# Grafana Auto-Provisioning Plan

> **Context:** Ephemeral GKE platform. Grafana is installed via the `grafana` subchart
> inside `kube-prometheus-stack`, managed by ArgoCD + Terraform/Terragrunt.
> Goal: dashboards, alert rules, contact points, and notification policies are
> fully provisioned on every fresh install — no manual UI steps.

---

## Overview

| What | Mechanism | Where configured |
|---|---|---|
| Dashboards | Sidecar + labelled ConfigMaps | Terraform `kubernetes_config_map` |
| Datasource UIDs | `additionalDataSources.uid` field | Grafana Helm values |
| Contact points | `alerting.contactpoints.yaml` | Grafana Helm values |
| Notification policy | `alerting.policies.yaml` | Grafana Helm values |
| Alert rules | `alerting.rules.yaml` | Grafana Helm values |
| Secrets (webhooks, tokens) | Kubernetes Secret → `envFromSecret` | Terraform + Grafana Helm values |

All provisioned resources appear **read-only** in the Grafana UI (locked padlock).
Edits must go through Terraform — correct behaviour for an ephemeral GitOps setup.

---

## Step 1 — Pin stable datasource UIDs

Before writing any alert rules, give each datasource an explicit `uid` so it
stays consistent across reinstalls. Alert rule `data` blocks reference these by UID.

In your Grafana Helm values (`additionalDataSources`):

```hcl
additionalDataSources = [
  {
    name      = "Prometheus"
    type      = "prometheus"
    uid       = "prometheus-main"          # add this
    url       = "http://prometheus-operated.monitoring.svc:9090"
    access    = "proxy"
    isDefault = true
  },
  {
    name   = "Loki"
    type   = "loki"
    uid    = "loki-main"                   # add this
    url    = "http://loki-gateway.logging.svc"
    access = "proxy"
  },
  {
    name   = "Tempo"
    type   = "tempo"
    uid    = "tempo-main"                  # add this
    url    = "http://tempo.tracing.svc:3200"
    access = "proxy"
  },
]
```

---

## Step 2 — Enable the dashboard sidecar

The sidecar watches for ConfigMaps with a specific label and hot-loads them into
Grafana. Replace the existing `sidecar` block in your Helm values:

```hcl
sidecar = {
  dashboards = {
    enabled         = true
    label           = "grafana_dashboard"
    labelValue      = "1"
    searchNamespace = "ALL"   # watches all namespaces
    folderAnnotation = "grafana_folder"   # optional: set folder per ConfigMap
    provider = {
      foldersFromFilesStructure = true
    }
  }
  datasources = {
    defaultDatasourceEnabled = false   # keep disabled; using additionalDataSources
  }
}
```

---

## Step 3 — Create dashboard ConfigMaps in Terraform

Place your dashboard JSON files in a `dashboards/` subdirectory next to your
Terraform module (e.g. `modules/grafana/dashboards/*.json`).

```hcl
# modules/grafana/dashboards.tf

resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = fileset("${path.module}/dashboards", "*.json")

  metadata {
    name      = "dashboard-${trimsuffix(each.value, ".json")}"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      # Optional: controls which folder the dashboard lands in inside Grafana
      grafana_folder = "Platform"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/${each.value}")
  }
}
```

To group dashboards into different folders, set `grafana_folder` per ConfigMap:

```hcl
# Example: separate folders by concern
locals {
  dashboard_folders = {
    "kubernetes-overview.json" = "Kubernetes"
    "loki-logs.json"           = "Logging"
    "users-microservice.json"  = "Microservices"
  }
}

resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = local.dashboard_folders

  metadata {
    name      = "dashboard-${trimsuffix(each.key, ".json")}"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels    = { grafana_dashboard = "1" }
    annotations = { grafana_folder = each.value }
  }

  data = {
    "${each.key}" = file("${path.module}/dashboards/${each.key}")
  }
}
```

---

## Step 4 — Create the alerting secrets

Sensitive values (webhook URLs, API keys) must never be inlined into Helm values.
Grafana expands `$__env{VAR_NAME}` inside provisioning files at runtime.

```hcl
# modules/grafana/secrets.tf

resource "kubernetes_secret" "grafana_alerting_secrets" {
  metadata {
    name      = "grafana-alerting-secrets"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  data = {
    SLACK_WEBHOOK_URL  = var.slack_webhook_url      # passed in via Terragrunt inputs
    PAGERDUTY_KEY      = var.pagerduty_key           # optional
    # Add other receiver credentials here
  }
}
```

Add the corresponding variables to your module `variables.tf`:

```hcl
variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

variable "pagerduty_key" {
  type      = string
  sensitive = true
  default   = ""
}
```

Store the actual values in GCP Secret Manager and pull them in Terragrunt via
`run_cmd` or a data source — consistent with your existing pattern for other
sensitive values on this platform.

---

## Step 5 — Wire the secret into Grafana

In your Grafana Helm values, add:

```hcl
grafana = {
  # ... existing config ...

  envFromSecret = kubernetes_secret.grafana_alerting_secrets.metadata[0].name
}
```

This mounts every key in the secret as an environment variable inside the
Grafana pod. Provisioning files can then reference them as `$__env{KEY_NAME}`.

---

## Step 6 — Add contact points

Inside your Grafana Helm values `grafana = { ... }` block, add an `alerting` key.
Each entry is a filename that becomes a file in
`/etc/grafana/provisioning/alerting/`.

```hcl
alerting = {
  "contactpoints.yaml" = {
    apiVersion = 1
    contactPoints = [
      {
        orgId = 1
        name  = "slack-platform"
        receivers = [
          {
            uid  = "slack-platform-receiver"
            type = "slack"
            settings = {
              url        = "$__env{SLACK_WEBHOOK_URL}"
              title      = "{{ template \"slack.default.title\" . }}"
              text       = "{{ template \"slack.default.text\" . }}"
              icon_emoji = ":grafana:"
              username   = "Grafana"
            }
            disableResolveMessage = false
          }
        ]
      }
    ]
  }
}
```

For additional receiver types (PagerDuty, email, etc.), add more objects to the
`receivers` list. Grafana's provisioning supports all receiver types available
in the UI.

---

## Step 7 — Add the notification policy

Extends the same `alerting` block:

```hcl
"policies.yaml" = {
  apiVersion = 1
  policies = [
    {
      orgId            = 1
      receiver         = "slack-platform"   # must match a contact point name above
      groupBy          = ["alertname", "namespace", "severity"]
      groupWait        = "30s"
      groupInterval    = "5m"
      repeatInterval   = "4h"
      routes = [
        {
          receiver = "slack-platform"
          matchers = ["severity=~\"warning|critical\""]
          continue = false
        }
      ]
    }
  ]
}
```

> The top-level `receiver` is the **default** catch-all. All unmatched alerts
> go here. Routes override it for specific matchers.

---

## Step 8 — Add alert rules

Extends the same `alerting` block. Each rule's `data` block references the
datasource UIDs pinned in Step 1.

```hcl
"rules.yaml" = {
  apiVersion = 1
  groups = [
    {
      orgId    = 1
      name     = "platform-alerts"
      folder   = "Platform"        # Grafana alert folder (not dashboard folder)
      interval = "1m"
      rules = [

        # ── Example: Node CPU saturation ──────────────────────────────────────
        {
          uid       = "node-cpu-high"
          title     = "Node CPU High"
          condition = "B"
          data = [
            {
              refId         = "A"
              datasourceUid = "prometheus-main"   # UID from Step 1
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = "100 - (avg by(node) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{ evaluator = { type = "gt", params = [85] }, query = { params = ["A"] } }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Node {{ $labels.node }} CPU above 85%"
            description = "Current value: {{ $value | printf \"%.1f\" }}%"
          }
          labels = { severity = "warning" }
        },

        # ── Example: Pod crash-looping ─────────────────────────────────────────
        {
          uid       = "pod-crashloop"
          title     = "Pod CrashLoopBackOff"
          condition = "B"
          data = [
            {
              refId         = "A"
              datasourceUid = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = "kube_pod_container_status_waiting_reason{reason=\"CrashLoopBackOff\"} == 1"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "2m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
            description = "Container {{ $labels.container }} has been in CrashLoopBackOff for > 2m"
          }
          labels = { severity = "critical" }
        },

      ]
    }
  ]
}
```

Add more groups (e.g. `loki-alerts`, `microservice-alerts`) as separate objects
in the `groups` list, each with their own `folder` and `interval`.

---

## Step 9 — Full Terraform resource (assembled)

The final `kubernetes_manifest.grafana` resource with all pieces wired together:

```hcl
resource "kubernetes_manifest" "grafana" {
  manifest = {
    # ... apiVersion, kind, metadata unchanged ...
    spec = {
      source = {
        helm = {
          values = yamlencode({
            # ... crds, defaultRules, disabled components unchanged ...

            grafana = {
              enabled                  = true
              defaultDashboardsEnabled = true

              admin = {
                existingSecret = kubernetes_secret.grafana_admin.metadata[0].name
                userKey        = "admin-user"
                passwordKey    = "admin-password"
              }

              envFromSecret = kubernetes_secret.grafana_alerting_secrets.metadata[0].name  # Step 5

              persistence = {
                enabled          = true
                type             = "pvc"
                size             = "5Gi"
                storageClassName = "standard"
                accessModes      = ["ReadWriteOnce"]
              }

              ingress = { enabled = false }

              sidecar = {                                          # Step 2
                dashboards = {
                  enabled          = true
                  label            = "grafana_dashboard"
                  labelValue       = "1"
                  searchNamespace  = "ALL"
                  folderAnnotation = "grafana_folder"
                }
                datasources = { defaultDatasourceEnabled = false }
              }

              additionalDataSources = [                           # Step 1
                {
                  name      = "Prometheus"
                  type      = "prometheus"
                  uid       = "prometheus-main"
                  url       = "http://prometheus-operated.monitoring.svc:9090"
                  access    = "proxy"
                  isDefault = true
                },
                {
                  name   = "Loki"
                  type   = "loki"
                  uid    = "loki-main"
                  url    = "http://loki-gateway.logging.svc"
                  access = "proxy"
                },
                {
                  name   = "Tempo"
                  type   = "tempo"
                  uid    = "tempo-main"
                  url    = "http://tempo.tracing.svc:3200"
                  access = "proxy"
                },
              ]

              "grafana.ini" = {
                server = { root_url = "https://grafana.${var.private_domain}" }
              }

              alerting = {                                        # Steps 6–8
                "contactpoints.yaml" = { ... }
                "policies.yaml"      = { ... }
                "rules.yaml"         = { ... }
              }
            }
          })
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.grafana_admin,
    kubernetes_secret.grafana_alerting_secrets,                  # Step 4
  ]
}
```

---

## Step 10 — Verify after apply

```bash
# 1. Sidecar picked up dashboards
kubectl logs -n grafana deployment/grafana -c grafana-sc-dashboard | grep -i "dashboard"

# 2. No provisioning errors in Grafana itself
kubectl logs -n grafana deployment/grafana -c grafana | grep -i "provision"

# 3. Alert rules loaded
kubectl port-forward -n grafana svc/grafana 3000:80
# → Alerting → Alert rules: should show your provisioned groups (locked padlock)

# 4. Contact points loaded
# → Alerting → Contact points: slack-platform should appear

# 5. Notification policy loaded
# → Alerting → Notification policies: routes should match your config
```

---

## Gotchas to watch out for

- **Rule UIDs must be globally unique** across all groups. Use descriptive slugs
  (`node-cpu-high`, `pod-crashloop`) rather than short IDs.
- **`yamlencode` and Go templates conflict.** Grafana alert annotation templates
  like `{{ $labels.node }}` contain `{{` which Terraform's `yamlencode` passes
  through safely, but double-check the rendered YAML if you see parse errors.
- **Provisioned resources are immutable from the UI.** To modify a rule or
  contact point, change the Terraform and let ArgoCD sync — do not edit in the
  UI, the change will be reverted on the next sync.
- **The `__expr__` datasource UID is a Grafana built-in** for threshold/math
  expressions; don't replace it with a real datasource UID.
- **Alert rule `data` blocks must include `relativeTimeRange`** even for
  expression nodes — omitting it causes silent rule evaluation failures.
