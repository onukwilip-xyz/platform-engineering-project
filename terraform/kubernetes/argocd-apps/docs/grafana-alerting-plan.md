# Grafana Alerting Plan — Contact Points, Policies & Rules

> **Routing strategy:** Every alert rule carries a `channel` label whose value
> matches a contact point name. Notification policies route purely on that label,
> keeping the policy tree flat and easy to reason about.

---

## 1. Contact Points

Four Slack channels. Each gets its own contact point in `contactpoints.yaml`.

```hcl
"contactpoints.yaml" = {
  apiVersion = 1
  contactPoints = [
    {
      orgId = 1
      name  = "scale-workloads"
      receivers = [{
        uid  = "cp-scale-workloads"
        type = "slack"
        settings = {
          url        = "$__env{SLACK_WEBHOOK_SCALE_WORKLOADS}"
          title      = "[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}"
          text       = "{{ range .Alerts }}*Namespace:* {{ .Labels.namespace }}\n*Pod:* {{ .Labels.pod }}\n*Message:* {{ .Annotations.description }}\n{{ end }}"
          icon_emoji = ":arrows_counterclockwise:"
          username   = "Grafana | Scale Workloads"
        }
        disableResolveMessage = false
      }]
    },
    {
      orgId = 1
      name  = "critical"
      receivers = [{
        uid  = "cp-critical"
        type = "slack"
        settings = {
          url        = "$__env{SLACK_WEBHOOK_CRITICAL}"
          title      = ":red_circle: [CRITICAL] {{ .GroupLabels.alertname }}"
          text       = "{{ range .Alerts }}*Namespace:* {{ .Labels.namespace }}\n*Resource:* {{ .Labels.name }}\n*Message:* {{ .Annotations.description }}\n{{ end }}"
          icon_emoji = ":red_circle:"
          username   = "Grafana | Critical"
        }
        disableResolveMessage = false
      }]
    },
    {
      orgId = 1
      name  = "error"
      receivers = [{
        uid  = "cp-error"
        type = "slack"
        settings = {
          url        = "$__env{SLACK_WEBHOOK_ERROR}"
          title      = ":warning: [ERROR] {{ .GroupLabels.alertname }}"
          text       = "{{ range .Alerts }}*Namespace:* {{ .Labels.namespace }}\n*Pod:* {{ .Labels.pod }}\n*Message:* {{ .Annotations.description }}\n{{ end }}"
          icon_emoji = ":warning:"
          username   = "Grafana | Error"
        }
        disableResolveMessage = false
      }]
    },
    {
      orgId = 1
      name  = "warning"
      receivers = [{
        uid  = "cp-warning"
        type = "slack"
        settings = {
          url        = "$__env{SLACK_WEBHOOK_WARNING}"
          title      = ":large_yellow_circle: [WARNING] {{ .GroupLabels.alertname }}"
          text       = "{{ range .Alerts }}*Namespace:* {{ .Labels.namespace }}\n*Message:* {{ .Annotations.description }}\n{{ end }}"
          icon_emoji = ":large_yellow_circle:"
          username   = "Grafana | Warning"
        }
        disableResolveMessage = false
      }]
    },
  ]
}
```

### Secrets to add

Add four keys to `kubernetes_secret.grafana_alerting_secrets`:

```hcl
data = {
  SLACK_WEBHOOK_SCALE_WORKLOADS = var.slack_webhook_scale_workloads
  SLACK_WEBHOOK_CRITICAL        = var.slack_webhook_critical
  SLACK_WEBHOOK_ERROR           = var.slack_webhook_error
  SLACK_WEBHOOK_WARNING         = var.slack_webhook_warning
}
```

---

## 2. Notification Policies

Routes on the `channel` label that every alert rule sets explicitly.
The default receiver catches anything that falls through.

```hcl
"policies.yaml" = {
  apiVersion = 1
  policies = [
    {
      orgId            = 1
      receiver         = "warning"       # default catch-all
      groupBy          = ["alertname", "namespace", "channel"]
      groupWait        = "30s"
      groupInterval    = "5m"
      repeatInterval   = "4h"
      routes = [
        {
          receiver = "critical"
          matchers = ["channel=\"critical\"", "alertname!=\"DatasourceError\"", "alertname!=\"DatasourceNoData\""]
          groupBy  = ["alertname", "namespace"]
          continue = false
        },
        {
          receiver = "error"
          matchers = ["channel=\"error\"", "alertname!=\"DatasourceError\"", "alertname!=\"DatasourceNoData\""]
          groupBy  = ["alertname", "namespace"]
          continue = false
        },
        {
          receiver = "scale-workloads"
          matchers = ["channel=\"scale-workloads\"", "alertname!=\"DatasourceError\"", "alertname!=\"DatasourceNoData\""]
          groupBy  = ["alertname", "namespace", "pod"]
          continue = false
        },
        {
          receiver = "warning"
          matchers = ["channel=\"warning\"", "alertname!=\"DatasourceError\"", "alertname!=\"DatasourceNoData\""]
          groupBy  = ["alertname", "namespace"]
          continue = false
        },
        {
          receiver = "default"
          matchers = ["alertname=\"DatasourceError\"", "alertname=\"DatasourceNoData\""]
          groupBy  = ["alertname", "namespace"]
          continue = false
        }
      ]
    }
  ]
}
```

---

## 3. Alert Rules

All rules live in `rules.yaml`. Organised into three groups.

### Routing label convention

Every rule sets `channel = "<cp-name>"` in its `labels` block. The notification
policy above picks this up and routes accordingly. Rules also set `severity` as
a human-readable label for the Grafana UI.

---

### Group 1 — Pod Health

```hcl
"rules.yaml" = {
  apiVersion = 1
  groups = [

    # ── Group 1: Pod Health ──────────────────────────────────────────────────
    {
      orgId    = 1
      name     = "pod-health"
      folder   = "Platform Alerts"
      interval = "1m"
      rules    = [

        # Rule 1a: General pod crash-looping (>=3 restarts)
        # Fires for any pod not in a designated critical namespace.
        {
          uid       = "pod-crashloop-error"
          title     = "Pod CrashLoopBackOff"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = "kube_pod_container_status_restarts_total{namespace!~\"postgres|cnpg-system\"} >= 3"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"           # must be restarting for 5 min straight
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
            description = "Container {{ $labels.container }} has restarted {{ $value }} times. Investigate with: kubectl logs {{ $labels.pod }} -n {{ $labels.namespace }} --previous"
          }
          labels = {
            severity = "error"
            channel  = "error"
          }
        },

        # Rule 1b: Critical pod crash-looping (postgres namespace)
        # Same query, scoped to critical namespaces only.
        {
          uid       = "pod-crashloop-critical"
          title     = "Critical Pod CrashLoopBackOff"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = "kube_pod_container_status_restarts_total{namespace=~\"postgres|cnpg-system\"} >= 3"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "2m"           # tighter window for critical workloads
          annotations = {
            summary     = "CRITICAL: Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
            description = "Container {{ $labels.container }} has restarted {{ $value }} times in a critical namespace. Immediate investigation required."
          }
          labels = {
            severity = "critical"
            channel  = "critical"
          }
        },

        # Rule 2: Pod approaching CPU limit (>80% of limit)
        {
          uid       = "pod-cpu-limit-80"
          title     = "Pod CPU Near Limit"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                # Ratio of usage to limit. Excludes pods with no CPU limit set (limit=0).
                expr  = <<-EOT
                  (
                    rate(container_cpu_usage_seconds_total{container!="", container!="POD", image!=""}[5m])
                    /
                    on(namespace, pod, container)
                    kube_pod_container_resource_limits{resource="cpu"}
                  ) > 0 and on(namespace, pod, container)
                  kube_pod_container_resource_limits{resource="cpu"} > 0
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0.80] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU at {{ $value | humanizePercentage }} of limit"
            description = "Container {{ $labels.container }} is using {{ $value | humanizePercentage }} of its CPU limit. Consider scaling or raising the limit."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        # Rule 3: Pod approaching memory limit (>80% of limit)
        {
          uid       = "pod-memory-limit-80"
          title     = "Pod Memory Near Limit"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    container_memory_working_set_bytes{container!="", container!="POD", image!=""}
                    /
                    on(namespace, pod, container)
                    kube_pod_container_resource_limits{resource="memory"}
                  ) > 0 and on(namespace, pod, container)
                  kube_pod_container_resource_limits{resource="memory"} > 0
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0.80] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} memory at {{ $value | humanizePercentage }} of limit"
            description = "Container {{ $labels.container }} is using {{ $value | humanizePercentage }} of its memory limit. OOMKill risk if this continues."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        # Rule: CPU throttle rate >25% (scale-workloads) and >50% (error)
        # Two separate rules using the same query with different thresholds.
        {
          uid       = "pod-cpu-throttle-rate-warning"
          title     = "Pod CPU Throttling High"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  sum by (namespace, pod, container) (
                    rate(container_cpu_cfs_throttled_periods_total{
                      container!="", container!="POD"
                    }[1m])
                  )
                  /
                  sum by (namespace, pod, container) (
                    rate(container_cpu_cfs_periods_total{
                      container!="", container!="POD"
                    }[1m])
                  ) * 100
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [25] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU throttled {{ $value | printf \"%.1f\" }}% of periods"
            description = "Container {{ $labels.container }} is being throttled >25% of CPU scheduling periods. Raise the CPU limit or reduce CPU request to allow more headroom."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        {
          uid       = "pod-cpu-throttle-rate-error"
          title     = "Pod CPU Throttling Severe"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  sum by (namespace, pod, container) (
                    rate(container_cpu_cfs_throttled_periods_total{
                      container!="", container!="POD"
                    }[1m])
                  )
                  /
                  sum by (namespace, pod, container) (
                    rate(container_cpu_cfs_periods_total{
                      container!="", container!="POD"
                    }[1m])
                  ) * 100
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [50] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU throttled {{ $value | printf \"%.1f\" }}% — probe failures likely"
            description = "Container {{ $labels.container }} is being throttled >50% of CPU scheduling periods. Liveness/readiness probe failures and request timeouts are likely. Immediate CPU limit increase needed."
          }
          labels = {
            severity = "error"
            channel  = "error"
          }
        },

        # Rule: CPU frozen time >0.25 s/s (scale-workloads) and >0.5 s/s (error)

        {
          uid       = "pod-cpu-throttle-seconds-warning"
          title     = "Pod CPU Frozen Time High"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  sum by (namespace, pod, container) (
                    rate(container_cpu_cfs_throttled_seconds_total{
                      container!="", container!="POD"
                    }[1m])
                  )
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0.25] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} frozen {{ $value | printf \"%.2f\" }}s per second"
            description = "Container {{ $labels.container }} is frozen >25% of wall-clock time due to CPU throttling. Consider increasing CPU limits."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        {
          uid       = "pod-cpu-throttle-seconds-error"
          title     = "Pod CPU Barely Running"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  sum by (namespace, pod, container) (
                    rate(container_cpu_cfs_throttled_seconds_total{
                      container!="", container!="POD"
                    }[1m])
                  )
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0.5] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} frozen {{ $value | printf \"%.2f\" }}s/s — barely running"
            description = "Container {{ $labels.container }} is frozen >50% of wall-clock time. This pod is effectively non-functional. Raise CPU limits immediately."
          }
          labels = {
            severity = "error"
            channel  = "error"
          }
        },

        # Rule 4: Pod stuck pending / unschedulable
        {
          uid       = "pod-unschedulable"
          title     = "Pod Unschedulable"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 600, to = 0 }
              model = {
                # kube_pod_status_unschedulable is set to 1 when the scheduler
                # cannot place the pod. Combine with Pending phase for robustness.
                expr  = "kube_pod_status_unschedulable == 1"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 600, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "10m"          # give scheduler time to resolve transient issues
          annotations = {
            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} cannot be scheduled"
            description = "Pod has been unschedulable for >10 minutes. Check node resources, taints, and affinities: kubectl describe pod {{ $labels.pod }} -n {{ $labels.namespace }}"
          }
          labels = {
            severity = "warning"
            channel  = "warning"
          }
        },

      ]
    },

    # ── Group 2: Deployment / StatefulSet Availability ───────────────────────
    {
      orgId    = 1
      name     = "workload-availability"
      folder   = "Platform Alerts"
      interval = "1m"
      rules    = [

        # Rule 5a: General Deployment with 0 available replicas
        {
          uid       = "deployment-zero-replicas-error"
          title     = "Deployment Zero Replicas"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    kube_deployment_status_replicas_available{namespace!~"postgres|cnpg-system"} == 0
                    and
                    kube_deployment_spec_replicas{namespace!~"postgres|cnpg-system"} > 0
                  )
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "3m"
          annotations = {
            summary     = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has 0 available replicas"
            description = "Deployment has {{ $value }} available replicas but spec requests > 0. Service may be down."
          }
          labels = {
            severity = "error"
            channel  = "error"
          }
        },

        # Rule 5b: General StatefulSet with 0 ready replicas
        {
          uid       = "statefulset-zero-replicas-error"
          title     = "StatefulSet Zero Replicas"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    kube_statefulset_status_replicas_ready{namespace!~"postgres|cnpg-system"} == 0
                    and
                    kube_statefulset_replicas{namespace!~"postgres|cnpg-system"} > 0
                  )
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "3m"
          annotations = {
            summary     = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has 0 ready replicas"
            description = "StatefulSet has 0 ready replicas but spec requests > 0. Stateful service may be down."
          }
          labels = {
            severity = "error"
            channel  = "error"
          }
        },

        # Rule 6a: Critical Deployment with 0 replicas (postgres namespaces)
        {
          uid       = "deployment-zero-replicas-critical"
          title     = "Critical Deployment Zero Replicas"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    kube_deployment_status_replicas_available{namespace=~"postgres|cnpg-system"} == 0
                    and
                    kube_deployment_spec_replicas{namespace=~"postgres|cnpg-system"} > 0
                  )
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "1m"           # tighter window; database outage is urgent
          annotations = {
            summary     = "CRITICAL: Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has 0 replicas"
            description = "Critical deployment is fully down. Immediate action required."
          }
          labels = {
            severity = "critical"
            channel  = "critical"
          }
        },

        # Rule 6b: Critical StatefulSet with 0 replicas (postgres namespaces)
        # CNPG Cluster pods are owned by a StatefulSet under the hood.
        {
          uid       = "statefulset-zero-replicas-critical"
          title     = "Critical StatefulSet Zero Replicas"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    kube_statefulset_status_replicas_ready{namespace=~"postgres|cnpg-system"} == 0
                    and
                    kube_statefulset_replicas{namespace=~"postgres|cnpg-system"} > 0
                  )
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "1m"
          annotations = {
            summary     = "CRITICAL: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has 0 ready replicas"
            description = "Critical stateful workload (likely CNPG cluster) is fully down. Immediate action required."
          }
          labels = {
            severity = "critical"
            channel  = "critical"
          }
        },

      ]
    },

    # ── Group 3: Node & Storage Health ───────────────────────────────────────
    {
      orgId    = 1
      name     = "node-and-storage"
      folder   = "Platform Alerts"
      interval = "1m"
      rules    = [

        # Rule 7: PVC disk usage >85%
        {
          uid       = "pvc-disk-85"
          title     = "PVC Disk Near Full"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    kubelet_volume_stats_used_bytes
                    /
                    kubelet_volume_stats_capacity_bytes
                  ) * 100
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [85] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "5m"
          annotations = {
            summary     = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is {{ $value | printf \"%.1f\" }}% full"
            description = "Volume is above 85% capacity. Expand the PVC or clean up data to avoid pod failures."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        # Rule 8a: Node CPU saturation >75%
        {
          uid       = "node-cpu-75"
          title     = "Node CPU Saturated"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = "100 - (avg by(node) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [75] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "10m"          # sustained saturation, not a spike
          annotations = {
            summary     = "Node {{ $labels.node }} CPU at {{ $value | printf \"%.1f\" }}%"
            description = "Node CPU has been above 75% for 10+ minutes. Consider adding nodes or moving workloads."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        # Rule 8b: Node memory saturation >75%
        {
          uid       = "node-memory-75"
          title     = "Node Memory Saturated"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = <<-EOT
                  (
                    (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
                    /
                    node_memory_MemTotal_bytes
                  ) * 100
                EOT
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [75] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "10m"
          annotations = {
            summary     = "Node {{ $labels.instance }} memory at {{ $value | printf \"%.1f\" }}%"
            description = "Node memory has been above 75% for 10+ minutes. OOMKill risk for pods without memory limits."
          }
          labels = {
            severity = "warning"
            channel  = "scale-workloads"
          }
        },

        # Rule 9: Node MemoryPressure condition
        # This fires from the Kubernetes node condition, not raw memory metrics.
        # It means the kubelet has already started evicting pods.
        {
          uid       = "node-memory-pressure"
          title     = "Node MemoryPressure"
          condition = "B"
          data = [
            {
              refId             = "A"
              datasourceUid     = "prometheus-main"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                expr  = "kube_node_status_condition{condition=\"MemoryPressure\",status=\"true\"} == 1"
                refId = "A"
              }
            },
            {
              refId         = "B"
              datasourceUid = "__expr__"
              relativeTimeRange = { from = 300, to = 0 }
              model = {
                type       = "threshold"
                refId      = "B"
                conditions = [{
                  evaluator = { type = "gt", params = [0] }
                  query     = { params = ["A"] }
                }]
              }
            }
          ]
          noDataState  = "NoData"
          execErrState = "Error"
          for          = "1m"           # condition set by kubelet — act immediately
          annotations = {
            summary     = "Node {{ $labels.node }} is under MemoryPressure"
            description = "Kubelet has set MemoryPressure=True on this node. Pod evictions may already be in progress. Check: kubectl describe node {{ $labels.node }}"
          }
          labels = {
            severity = "warning"
            channel  = "warning"
          }
        },

      ]
    },

  ]
}
```

---

## 4. Namespace regex — adjusting for your cluster

The critical namespace filter `namespace=~"postgres|cnpg-system"` is used to
split general vs critical alerts. Update this regex to match your actual
namespace names if they differ.

If you want to mark additional namespaces as critical without changing the
alert rule PromQL, an alternative approach is to label the namespaces:

```bash
kubectl label namespace postgres criticality=high
kubectl label namespace cnpg-system criticality=high
```

Then change the filter to:
```
namespace=~"{{ range $ns := .critical_namespaces }}{{ $ns }}|{{ end }}"
```

Or simply keep the explicit regex — it's clearer for an ephemeral setup.

---

## 5. CNPG Cluster — note on StatefulSet visibility

CNPG creates pods directly (not via a StatefulSet), so
`kube_statefulset_status_replicas_ready` won't capture a downed CNPG cluster.
For full CNPG coverage, add a dedicated rule using CNPG's own metrics if the
CNPG operator exposes them, or use a pod-count approach:

```promql
# Fires if the postgres cluster has 0 ready pods
(
  count by(namespace) (
    kube_pod_status_ready{namespace="postgres", condition="true"}
  ) == 0
)
or
(
  absent(kube_pod_status_ready{namespace="postgres", condition="true"})
)
```

Add this as an additional rule in the `workload-availability` group with
`channel = "critical"`.

---

## 6. Summary — alert → channel mapping

| Alert | Fires after | Channel |
|---|---|---|
| Pod CrashLoopBackOff (general) | 3 restarts, 5 min | `error` |
| Pod CrashLoopBackOff (critical ns) | 3 restarts, 2 min | `critical` |
| Pod CPU >80% of limit | 5 min | `scale-workloads` |
| Pod Memory >80% of limit | 5 min | `scale-workloads` |
| Pod Throttled 25% of the time | 5 min | `scale-workloads` |
| Pod Throttled 50% of the time | 5 min | `error` |
| Pod unschedulable | 10 min | `warning` |
| Deployment 0 replicas (general) | 3 min | `error` |
| StatefulSet 0 replicas (general) | 3 min | `error` |
| Deployment 0 replicas (critical ns) | 1 min | `critical` |
| StatefulSet 0 replicas (critical ns) | 1 min | `critical` |
| PVC >85% full | 5 min | `scale-workloads` |
| Node CPU >75% | 10 min | `scale-workloads` |
| Node Memory >75% | 10 min | `scale-workloads` |
| Node MemoryPressure | 1 min | `warning` |
