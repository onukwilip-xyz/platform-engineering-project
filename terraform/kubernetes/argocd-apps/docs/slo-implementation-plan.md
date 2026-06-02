# SLO Implementation Plan — Platform Engineering Project

> **Scope:** Availability and latency SLOs for `users-microservice` and `store-ui`,
> plus availability SLO for the CNPG PostgreSQL cluster.
> **Tooling:** Sloth operator (SLO → recording rules), Grafana alerting (no Alertmanager).
> **This doc lives at:** `terraform/kubernetes/argocd-apps/docs/slo-implementation-plan.md`

---

## Architecture Fit

```
Sloth Operator (monitoring ns)
  ├── Watches: PrometheusServiceLevel CRDs (all namespaces)
  └── Generates: PrometheusRule CRDs  ──►  Prometheus Operator picks up automatically
                                               └── Recording rules available in Prometheus
                                                      └── Grafana alert rules query them
```

**Why no Alertmanager:** Sloth also generates `PrometheusRule` alert rules, but since
you run Grafana's built-in alerting instead of Alertmanager, those alert rules are
unused. You will inspect them after install to understand the metric names and
multi-window thresholds Sloth chose, then replicate equivalent rules in Grafana.

**Istio coverage:** Both `users` and `store-ui` namespaces have
`istio-injection=enabled`. Envoy sidecars emit `istio_requests_total` and
`istio_request_duration_milliseconds_bucket` for every request — no application
instrumentation needed.

**CNPG coverage:** The `postgres` namespace is intentionally off-mesh. SLI data
comes from CNPG's own Prometheus metrics (`cnpg_cluster_ready_instances`), already
scraped by kube-prometheus-stack.

---

## Step 1 — Install Sloth Operator via ArgoCD

Add to `terraform/kubernetes/argocd-apps/applications.tf` alongside the existing
16 applications. Sloth must come after `kube-prometheus-stack` (app #3) since it
creates `PrometheusRule` CRDs that the Prometheus Operator must be present to watch.

```hcl
resource "kubernetes_manifest" "sloth" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "sloth"
      namespace = var.argocd_namespace
      annotations = {
        # Wave 4 — after kube-prometheus-stack (wave 1) and grafana (wave 3)
        "argocd.argoproj.io/sync-wave"       = "4"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://slok.github.io/sloth"
        chart          = "sloth"
        targetRevision = "0.11.0"
        helm = {
          values = yamlencode({
            # Sloth runs as a controller watching PrometheusServiceLevel CRDs
            # cluster-wide and emitting PrometheusRule CRDs into the same namespace
            # as the SLO CR. No special Workload Identity needed.

            customPrometheusRules = {
              enabled = true
            }

            # Sloth's own metrics — scraped by the existing kube-prometheus-stack
            serviceMonitor = {
              enabled = true
            }

            resources = {
              requests = { cpu = "50m", memory = "64Mi" }
              limits   = { cpu = "200m", memory = "128Mi" }
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "monitoring"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=false",
          "ServerSideApply=true",
          "ServerSideDiff=true",
        ]
      }
    }
  }

  # Sloth creates PrometheusRule CRDs — Prometheus Operator must be running first
  depends_on = [kubernetes_manifest.kube_prometheus_stack]
}
```

### Verify install

```bash
# Operator running
kubectl get deploy sloth -n monitoring

# CRD installed
kubectl get crd prometheusservicelevels.sloth.slok.dev

# Sloth logs (should show "watching for PrometheusServiceLevel resources")
kubectl logs -n monitoring deploy/sloth | tail -20
```

---

## Step 2 — Add SLO CRs to Microservice Helm Charts

Each microservice's Helm chart gets a `templates/slo.yaml` file containing the
`PrometheusServiceLevel` CR. Sloth watches this CR and generates the corresponding
`PrometheusRule` (recording rules + alert rules) in the same namespace.

### 2a — Users Microservice

**File:** `helm/users-microservice/templates/slo.yaml`

```yaml
{{- if .Values.slo.enabled }}
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: users-microservice
  namespace: {{ .Release.Namespace }}
  labels:
    app: users-microservice
    team: platform
spec:
  service: "users-microservice"
  labels:
    team: platform
    tier: microservice
    namespace: {{ .Release.Namespace }}

  slos:

    # ── SLO 1: Request Availability ─────────────────────────────────────────
    # 99.5% of requests to the Users service must return non-5xx responses.
    # SLI source: Istio Envoy sidecar (istio_requests_total).
    - name: requests-availability
      objective: {{ .Values.slo.availability.objective | default 99.5 }}
      description: >
        {{ .Values.slo.availability.objective | default 99.5 }}% of HTTP requests
        to the Users microservice must return a non-5xx response over a 30-day window.
      sli:
        events:
          # Error events: 5xx responses
          errorQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "users-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}",
              response_code=~"5.."
            }[{{`{{.window}}`}}]))
          # Total events: all requests
          totalQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "users-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}"
            }[{{`{{.window}}`}}]))
      alerting:
        name: UsersServiceHighErrorRate
        labels:
          tier: microservice
          service: users-microservice
        annotations:
          summary: "Users service error rate is burning through the error budget"
          runbook: "https://argocd.internal.pe.onukwilip.xyz/applications/users-microservice"
        # Page alert — fast burn rate (Sloth generates multi-window alert)
        pageAlert:
          labels:
            channel: critical
            severity: critical
        # Ticket alert — slow burn rate
        ticketAlert:
          labels:
            channel: error
            severity: error

    # ── SLO 2: Request Latency ───────────────────────────────────────────────
    # 99% of requests to the Users service must complete within 500ms.
    # SLI source: Istio Envoy sidecar histogram.
    - name: requests-latency
      objective: {{ .Values.slo.latency.objective | default 99.0 }}
      description: >
        {{ .Values.slo.latency.objective | default 99.0 }}% of HTTP requests
        to the Users microservice must complete within
        {{ .Values.slo.latency.thresholdMs | default 500 }}ms over a 30-day window.
      sli:
        events:
          # Error events: requests that took LONGER than the threshold
          # (total minus those within the threshold = slow requests)
          errorQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "users-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}"
            }[{{`{{.window}}`}}]))
            -
            sum(rate(istio_request_duration_milliseconds_bucket{
              destination_service_name="{{ .Values.service.name | default "users-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}",
              le="{{ .Values.slo.latency.thresholdMs | default 500 }}"
            }[{{`{{.window}}`}}]))
          # Total events: all requests
          totalQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "users-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}"
            }[{{`{{.window}}`}}]))
      alerting:
        name: UsersServiceHighLatency
        labels:
          tier: microservice
          service: users-microservice
        annotations:
          summary: "Users service latency is burning through the error budget"
        pageAlert:
          labels:
            channel: error
            severity: error
        ticketAlert:
          labels:
            channel: scale-workloads
            severity: warning
{{- end }}
```

**Add to `helm/users-microservice/values.yaml`:**

```yaml
slo:
  enabled: true

  availability:
    objective: 99.5   # 99.5% of requests must be non-5xx

  latency:
    objective: 99.0   # 99% of requests must complete within thresholdMs
    thresholdMs: 500  # milliseconds — must match an existing Istio histogram bucket
                      # Istio default buckets: 1,5,10,25,50,100,250,500,1000,2500,5000,10000

service:
  name: users-service  # must match the Kubernetes Service name exactly
```

---

### 2b — Store UI Microservice

**File:** `helm/store-ui/templates/slo.yaml`

Same structure as the users microservice. Key differences: service name and
potentially different objectives (a UI can tolerate slightly higher error rates
than a backend API).

```yaml
{{- if .Values.slo.enabled }}
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: store-ui
  namespace: {{ .Release.Namespace }}
  labels:
    app: store-ui
    team: platform
spec:
  service: "store-ui"
  labels:
    team: platform
    tier: frontend

  slos:

    - name: requests-availability
      objective: {{ .Values.slo.availability.objective | default 99.0 }}
      description: >
        {{ .Values.slo.availability.objective | default 99.0 }}% of HTTP requests
        to Store UI must return non-5xx responses over a 30-day window.
      sli:
        events:
          errorQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "store-ui-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}",
              response_code=~"5.."
            }[{{`{{.window}}`}}]))
          totalQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "store-ui-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}"
            }[{{`{{.window}}`}}]))
      alerting:
        name: StoreUIHighErrorRate
        labels:
          tier: frontend
          service: store-ui
        pageAlert:
          labels:
            channel: error
            severity: error
        ticketAlert:
          labels:
            channel: warning
            severity: warning

    - name: requests-latency
      objective: {{ .Values.slo.latency.objective | default 99.0 }}
      description: >
        {{ .Values.slo.latency.objective | default 99.0 }}% of requests to
        Store UI must complete within {{ .Values.slo.latency.thresholdMs | default 1000 }}ms.
      sli:
        events:
          errorQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "store-ui-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}"
            }[{{`{{.window}}`}}]))
            -
            sum(rate(istio_request_duration_milliseconds_bucket{
              destination_service_name="{{ .Values.service.name | default "store-ui-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}",
              le="{{ .Values.slo.latency.thresholdMs | default 1000 }}"
            }[{{`{{.window}}`}}]))
          totalQuery: |
            sum(rate(istio_requests_total{
              destination_service_name="{{ .Values.service.name | default "store-ui-service" }}",
              destination_service_namespace="{{ .Release.Namespace }}"
            }[{{`{{.window}}`}}]))
      alerting:
        name: StoreUIHighLatency
        labels:
          tier: frontend
          service: store-ui
        pageAlert:
          labels:
            channel: error
            severity: error
        ticketAlert:
          labels:
            channel: scale-workloads
            severity: warning
{{- end }}
```

**`helm/store-ui/values.yaml` additions:**

```yaml
slo:
  enabled: true
  availability:
    objective: 99.0
  latency:
    objective: 99.0
    thresholdMs: 1000  # UI can tolerate 1s; use 500 if you want tighter

service:
  name: store-ui-service
```

---

### 2c — CNPG PostgreSQL Cluster

The CNPG SLO CR does not belong in a microservice chart. The two options:

**Option A (recommended):** Add a `templates/slo.yaml` to your existing
`postgres-cluster` Helm chart (if it's a custom chart in `helm/`).

**Option B:** Add it as a raw Kubernetes manifest in
`terraform/kubernetes/manifests/` alongside existing postgres manifests,
applied via a separate `kubernetes_manifest` Terraform resource.

Using Option B since CNPG is managed via ArgoCD app pointing to the cluster chart:

```hcl
# terraform/kubernetes/argocd-apps/applications.tf — add alongside other manifests

resource "kubernetes_manifest" "cnpg_slo" {
  manifest = {
    apiVersion = "sloth.slok.dev/v1"
    kind       = "PrometheusServiceLevel"
    metadata = {
      name      = "postgres-cluster"
      namespace = "monitoring"   # place in monitoring ns so PrometheusRule lands here
      labels    = { team = "platform", tier = "database" }
    }
    spec = {
      service = "postgres-cluster"
      labels  = { team = "platform", tier = "database" }

      slos = [
        {
          name        = "cluster-availability"
          objective   = 99.9
          description = "99.9% of time, the CNPG cluster must have at least 1 ready instance."

          sli = {
            events = {
              # Error events: seconds where NO instance is ready
              # clamp_min prevents negative values if ready > total (shouldn't happen)
              errorQuery = <<-EOT
                clamp_min(
                  sum(cnpg_cluster_instances{cluster="postgres-cluster"})
                  -
                  sum(cnpg_cluster_ready_instances{cluster="postgres-cluster"}),
                0)
              EOT

              # Total events: total instance-seconds (baseline denominator)
              totalQuery = "sum(cnpg_cluster_instances{cluster=\"postgres-cluster\"})"
            }
          }

          alerting = {
            name = "PostgresClusterUnavailable"
            labels = { tier = "database", service = "postgres-cluster" }
            annotations = {
              summary = "CNPG postgres-cluster has no ready instances"
              description = "Database is unavailable. Check CNPG operator and pod status in the postgres namespace."
            }
            pageAlert = {
              labels = { channel = "critical", severity = "critical" }
            }
            ticketAlert = {
              labels = { channel = "error", severity = "error" }
            }
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.sloth]
}
```

---

## Step 3 — Verify Generated PrometheusRules

After ArgoCD syncs, Sloth generates a `PrometheusRule` CRD for each
`PrometheusServiceLevel`. The Prometheus Operator picks these up automatically
(it already watches all namespaces for PrometheusRule CRDs per your
kube-prometheus-stack config).

```bash
# List generated PrometheusRules
kubectl get prometheusrule -n users
kubectl get prometheusrule -n store-ui
kubectl get prometheusrule -n monitoring   # CNPG SLO

# Inspect the users microservice generated rule — THIS IS THE KEY STEP
# Read the exact recording rule metric names before writing Grafana alerts
kubectl get prometheusrule users-microservice -n users -o yaml
```

The output will contain two sections per SLO:

**Recording rules** — these are the metrics you'll query in Grafana:
```yaml
groups:
  - name: sloth-slo-sli-recordings-users-microservice-requests-availability
    rules:
      - record: slo:sli_error:ratio_rate5m     # ← note these exact names
        expr: ...
        labels:
          sloth_service: users-microservice
          sloth_slo: requests-availability
          sloth_window: 5m
      - record: slo:sli_error:ratio_rate30m
      - record: slo:sli_error:ratio_rate1h
      - record: slo:sli_error:ratio_rate2h
      - record: slo:sli_error:ratio_rate6h
      - record: slo:sli_error:ratio_rate1d
      - record: slo:sli_error:ratio_rate3d
      - record: slo:sli_error:ratio_rate30d

  - name: sloth-slo-meta-recordings-users-microservice-requests-availability
    rules:
      - record: sloth_slo_objective_ratio       # SLO target as a ratio (0.995)
      - record: sloth_slo_error_budget_ratio    # remaining budget (1.0 → 0.0 → negative)
      - record: sloth_slo_time_period_days      # 30
      - record: sloth_slo_current_burn_rate_ratio  # current 5m burn rate
```

**Alert rules** — read these to understand Sloth's multi-window thresholds,
then replicate them in Grafana (Step 4):
```yaml
  - name: sloth-slo-alerts-users-microservice-requests-availability
    rules:
      # Page alert (fast burn) — conditions to replicate in Grafana
      - alert: UsersServiceHighErrorRate
        expr: |
          (
            slo:sli_error:ratio_rate1h{...} > (14.4 * 0.005)
            and
            slo:sli_error:ratio_rate5m{...} > (14.4 * 0.005)
          )
          or
          (
            slo:sli_error:ratio_rate6h{...} > (6 * 0.005)
            and
            slo:sli_error:ratio_rate30m{...} > (6 * 0.005)
          )
        labels:
          severity: page
          sloth_severity: page
          ...

      # Ticket alert (slow burn)
      - alert: UsersServiceHighErrorRate
        expr: |
          ...
```

> **Important:** Sloth's alert rule threshold is expressed as the **raw error ratio**
> (`burn_rate × (1 - objective)`), not the burn rate multiplier directly.
> For a 99.5% SLO: `14.4 × (1 - 0.995) = 14.4 × 0.005 = 0.072`
> That means: "fire if more than 7.2% of requests are failing" (sustained over both windows).

Verify recording rules are being evaluated by Prometheus:
```bash
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090

# In browser: http://localhost:9090/rules
# Look for rule groups named sloth-slo-*

# Or query directly
curl "http://localhost:9090/api/v1/query?query=sloth_slo_error_budget_ratio"
```

---

## Step 4 — Write Grafana Alert Rules

Once recording rule metric names are confirmed from Step 3, add these rules to
`terraform/kubernetes/argocd-apps/grafana-alerting/rules.yaml`.

### Pattern: multi-window alert in Grafana

Each Grafana alert rule needs three query refs:
- `A` = short window recording rule from Prometheus
- `B` = long window recording rule from Prometheus
- `C` = math expression requiring BOTH A and B to exceed the threshold
- `D` = threshold condition on C

```yaml
# ── SLO Group ────────────────────────────────────────────────────────────────

- orgId: 1
  name: slo-alerts
  folder: Platform Alerts
  interval: 1m
  rules:

    # Users availability — page alert (fast burn: 1h + 5m, threshold 14.4x)
    - uid: slo-users-availability-page
      title: "SLO: Users Service Availability Fast Burn"
      condition: D
      noDataState: OK
      execErrState: Error
      for: 2m
      labels:
        channel: critical
        severity: critical
      annotations:
        summary: "Users service burning error budget at >14.4x rate"
        description: >
          Fast burn detected. 1h error ratio: {{ $values.A.Value | printf "%.4f" }},
          5m error ratio: {{ $values.B.Value | printf "%.4f" }}.
          At this rate, the 30-day error budget exhausts in ~2 days.
      data:
        # Long window (1h)
        - refId: A
          datasourceUid: prometheus-main
          relativeTimeRange: { from: 300, to: 0 }
          model:
            expr: >
              slo:sli_error:ratio_rate1h{
                sloth_service="users-microservice",
                sloth_slo="requests-availability"
              }
            instant: true
            intervalMs: 1000
            maxDataPoints: 43200
            refId: A
        # Short window (5m)
        - refId: B
          datasourceUid: prometheus-main
          relativeTimeRange: { from: 300, to: 0 }
          model:
            expr: >
              slo:sli_error:ratio_rate5m{
                sloth_service="users-microservice",
                sloth_slo="requests-availability"
              }
            instant: true
            intervalMs: 1000
            maxDataPoints: 43200
            refId: B
        # Math: BOTH windows must exceed threshold
        # Threshold = burn_rate × (1 - objective) = 14.4 × (1 - 0.995) = 0.072
        - refId: C
          datasourceUid: __expr__
          relativeTimeRange: { from: 300, to: 0 }
          model:
            type: math
            refId: C
            expression: "$A > 0.072 && $B > 0.072"
        # Condition: C > 0
        - refId: D
          datasourceUid: __expr__
          relativeTimeRange: { from: 300, to: 0 }
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator: { type: gt, params: [0] }
                query: { params: [C] }

    # Users availability — ticket alert (slow burn: 6h + 30m, threshold 6x)
    - uid: slo-users-availability-ticket
      title: "SLO: Users Service Availability Slow Burn"
      condition: D
      noDataState: OK
      execErrState: Error
      for: 15m
      labels:
        channel: error
        severity: error
      annotations:
        summary: "Users service slowly burning error budget at >6x rate"
        description: >
          Slow burn detected. 6h error ratio: {{ $values.A.Value | printf "%.4f" }},
          30m error ratio: {{ $values.B.Value | printf "%.4f" }}.
          At this rate, the error budget exhausts in ~5 days.
      data:
        - refId: A
          datasourceUid: prometheus-main
          relativeTimeRange: { from: 300, to: 0 }
          model:
            expr: >
              slo:sli_error:ratio_rate6h{
                sloth_service="users-microservice",
                sloth_slo="requests-availability"
              }
            instant: true
            intervalMs: 1000
            maxDataPoints: 43200
            refId: A
        - refId: B
          datasourceUid: prometheus-main
          relativeTimeRange: { from: 300, to: 0 }
          model:
            expr: >
              slo:sli_error:ratio_rate30m{
                sloth_service="users-microservice",
                sloth_slo="requests-availability"
              }
            instant: true
            intervalMs: 1000
            maxDataPoints: 43200
            refId: B
        - refId: C
          datasourceUid: __expr__
          relativeTimeRange: { from: 300, to: 0 }
          model:
            type: math
            refId: C
            # Threshold = 6 × (1 - 0.995) = 0.030
            expression: "$A > 0.030 && $B > 0.030"
        - refId: D
          datasourceUid: __expr__
          relativeTimeRange: { from: 300, to: 0 }
          model:
            type: threshold
            refId: D
            expression: C
            conditions:
              - evaluator: { type: gt, params: [0] }
                query: { params: [C] }
```

### Threshold formula (apply to all services)

Before writing each alert, calculate the correct threshold:

```
threshold = burn_rate_multiplier × (1 - SLO_objective_as_ratio)

Users availability (99.5% SLO):
  Page  (14.4x): 14.4 × (1 - 0.995) = 14.4 × 0.005 = 0.072
  Ticket  (6x):  6   × (1 - 0.995) =  6  × 0.005 = 0.030

Users latency (99.0% SLO):
  Page  (14.4x): 14.4 × (1 - 0.99) = 14.4 × 0.01 = 0.144
  Ticket  (6x):  6   × (1 - 0.99) =  6  × 0.01 = 0.060

Store UI availability (99.0% SLO):
  Page  (14.4x): 14.4 × 0.01 = 0.144
  Ticket  (6x):  6   × 0.01 = 0.060

CNPG availability (99.9% SLO):
  Page  (14.4x): 14.4 × (1 - 0.999) = 14.4 × 0.001 = 0.01440
  Ticket  (6x):  6   × 0.001        =                  0.00600
```

Create one page alert + one ticket alert for each of the 5 SLOs:
- `users-microservice` / `requests-availability`
- `users-microservice` / `requests-latency`
- `store-ui` / `requests-availability`
- `store-ui` / `requests-latency`
- `postgres-cluster` / `cluster-availability`

---

## Step 5 — Add SLO Dashboard to Grafana

Sloth ships pre-built Grafana dashboards. Import them via ConfigMap so they are
auto-provisioned like your existing dashboards.

Download the dashboard JSONs:
```bash
# Sloth Overview — all services at a glance
curl -o terraform/kubernetes/argocd-apps/grafana-dashboards/sloth-slo-overview.json \
  https://raw.githubusercontent.com/slok/sloth/main/pkg/grafana/dashboards/slo-overview.json

# Sloth Detail — per-SLO burn rate and budget
curl -o terraform/kubernetes/argocd-apps/grafana-dashboards/sloth-slo-detail.json \
  https://raw.githubusercontent.com/slok/sloth/main/pkg/grafana/dashboards/slo-detail.json
```

These dashboards use `${DS_PROMETHEUS}` as the datasource variable. Apply the
same `replace()` fix used for other dashboards in your ConfigMap resource:

```hcl
# These are already covered by your existing grafana_dashboards ConfigMap resource
# since it uses for_each = local.dashboard_folders and reads all JSON files from
# the grafana-dashboards/ directory. Just add the two files to that directory
# and update local.dashboard_folders:

locals {
  dashboard_folders = {
    ...existing entries...
    "sloth-slo-overview.json" = "SLOs"
    "sloth-slo-detail.json"   = "SLOs"
  }
}
```

---

## Step 6 — Verify End-to-End

```bash
# 1. PrometheusServiceLevel CRs are created
kubectl get prometheusservicelevel -A

# 2. Sloth generated the PrometheusRules
kubectl get prometheusrule -A | grep sloth

# 3. Recording rules appear in Prometheus
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
# → http://localhost:9090/graph
# Query: sloth_slo_error_budget_ratio
# Should return one time series per SLO with value near 1.0 (budget mostly intact)

# 4. Error budget dashboard shows data in Grafana
# → Dashboards > SLOs > Sloth SLO Overview

# 5. Burn rate is visible
# Query: sloth_slo_current_burn_rate_ratio
# Should be near 1.0 under normal load (burning at baseline rate)

# 6. Test an alert fires correctly (optional)
# Scale users deployment to 0 replicas to trigger 5xx cascade,
# observe burn rate spike in Grafana, confirm alert fires to #critical channel
kubectl scale deploy users-microservice -n users --replicas=0
# wait 2 minutes, check Grafana > Alerting > Alert rules
kubectl scale deploy users-microservice -n users --replicas=<original>
```

---

## Summary — Files Changed

| File | Change |
|---|---|
| `terraform/kubernetes/argocd-apps/applications.tf` | Add `sloth` ArgoCD application + `cnpg_slo` manifest |
| `helm/users-microservice/templates/slo.yaml` | New file — PrometheusServiceLevel CR |
| `helm/users-microservice/values.yaml` | Add `slo:` block |
| `helm/store-ui/templates/slo.yaml` | New file — PrometheusServiceLevel CR |
| `helm/store-ui/values.yaml` | Add `slo:` block |
| `terraform/kubernetes/argocd-apps/grafana-alerting/rules.yaml` | Add `slo-alerts` group (10 new rules: 2 per SLO × 5 SLOs) |
| `terraform/kubernetes/argocd-apps/grafana-dashboards/sloth-slo-overview.json` | New — download from Sloth repo |
| `terraform/kubernetes/argocd-apps/grafana-dashboards/sloth-slo-detail.json` | New — download from Sloth repo |

---

## SLO Reference Table

| Service | SLO | Objective | Window | Page threshold | Ticket threshold |
|---|---|---|---|---|---|
| users-microservice | Availability | 99.5% | 30d | 14.4x (0.072) | 6x (0.030) |
| users-microservice | Latency <500ms | 99.0% | 30d | 14.4x (0.144) | 6x (0.060) |
| store-ui | Availability | 99.0% | 30d | 14.4x (0.144) | 6x (0.060) |
| store-ui | Latency <1000ms | 99.0% | 30d | 14.4x (0.144) | 6x (0.060) |
| postgres-cluster | Availability | 99.9% | 30d | 14.4x (0.01440) | 6x (0.00600) |
