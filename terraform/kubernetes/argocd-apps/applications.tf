# * POSTGRESQL CLUSTER STACK

# CNPG Operator
resource "kubernetes_manifest" "cnpg_operator" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "cnpg-operator"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "0"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://cloudnative-pg.github.io/charts"
        chart          = "cloudnative-pg"
        targetRevision = var.cnpg_operator_chart_version
        helm = {
          values = <<-EOT
            config:
              clusterWide: true
          EOT
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.cnpg_system.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }
}

# PostgreSQL Cluster
resource "kubernetes_manifest" "postgres_cluster" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "postgres-cluster"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "terraform/kubernetes/manifests/postgres"
        helm = {
          values = yamlencode({
            backup = {
              gcpServiceAccount = var.backup_gcp_sa_email
              bucketName        = var.backup_bucket_name
            }
            pooler = {
              loadBalancerIP = var.shared_vip_address
            }
            certificates = {
              clusterIssuer = var.cluster_issuer_name
            }
            databases = [
              {
                name               = local.users_db_name
                owner              = local.users_db_username
                passwordSecretName = kubernetes_secret.users_db_credentials.metadata[0].name
              },
            ]
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "postgres"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.cnpg_operator,
    kubernetes_secret.users_db_credentials,
  ]
}

# * OBSERVABILITY STACK

# Prometheus + Operator + kube-state-metrics + node-exporter.
resource "kubernetes_manifest" "kube_prometheus_stack" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "kube-prometheus-stack"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "2"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://prometheus-community.github.io/helm-charts"
        chart          = "kube-prometheus-stack"
        targetRevision = var.kube_prometheus_stack_chart_version
        helm = {
          values = yamlencode({
            # Grafana is installed separately in the `grafana` namespace.
            grafana = {
              enabled = false
            }

            prometheus = {
              prometheusSpec = {
                # `Nil…SelectorNilUsesHelmValues = false` lets Prometheus discover
                # ServiceMonitors / PodMonitors / PrometheusRules / Probes created
                # in other namespaces (grafana, logging, tracing, microservices…).
                serviceMonitorSelectorNilUsesHelmValues = false
                podMonitorSelectorNilUsesHelmValues     = false
                ruleSelectorNilUsesHelmValues           = false
                probeSelectorNilUsesHelmValues          = false
                enableRemoteWriteReceiver               = true
                retention                               = "7d"

                storageSpec = {
                  volumeClaimTemplate = {
                    spec = {
                      storageClassName = "standard"
                      accessModes      = ["ReadWriteOnce"]
                      resources = {
                        requests = {
                          storage = "10Gi"
                        }
                      }
                    }
                  }
                }
              }
            }

            # node-exporter runs with hostNetwork=true; ambient CNI can't redirect
            # hostNetwork pods, so opt the DaemonSet out of the mesh.
            "prometheus-node-exporter" = {
              podLabels = {
                "istio.io/dataplane-mode" = "none"
              }
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.monitoring.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        # ServerSideApply handles the large CRDs (Prometheus / Alertmanager) that
        # overflow the client-side last-applied annotation limit.
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }
}

# Grafana — only the `grafana` subchart enabled in the KPS chart so we inherit the default dashboards
resource "kubernetes_manifest" "grafana" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "grafana"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "3"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://prometheus-community.github.io/helm-charts"
        chart          = "kube-prometheus-stack"
        targetRevision = var.kube_prometheus_stack_chart_version
        helm = {
          values = yamlencode({
            # CRDs ship with the monitoring release; don't re-apply them here.
            crds = { enabled = false }

            # Everything non-Grafana is already running in the monitoring release.
            defaultRules          = { create = false }
            alertmanager          = { enabled = false }
            prometheus            = { enabled = false }
            prometheusOperator    = { enabled = false }
            kubeStateMetrics      = { enabled = false }
            nodeExporter          = { enabled = false }
            kubeApiServer         = { enabled = false }
            kubelet               = { enabled = false }
            kubeControllerManager = { enabled = false }
            coreDns               = { enabled = false }
            kubeDns               = { enabled = false }
            kubeEtcd              = { enabled = false }
            kubeScheduler         = { enabled = false }
            kubeProxy             = { enabled = false }

            grafana = {
              enabled                  = true
              defaultDashboardsEnabled = true

              admin = {
                existingSecret = kubernetes_secret.grafana_admin.metadata[0].name
                userKey        = "admin-user"
                passwordKey    = "admin-password"
              }

              persistence = {
                enabled          = true
                type             = "pvc"
                size             = "5Gi"
                storageClassName = "standard"
                accessModes      = ["ReadWriteOnce"]
              }

              # HTTPRoute through the private Gateway is added separately.
              ingress = { enabled = false }

              sidecar = {
                # Watches grafana_alert=1 ConfigMaps, mounts them as raw files
                # into /etc/grafana/provisioning/alerting/ — no tpl processing,
                # so Grafana's own {{ }} template syntax works correctly.
                alerts = {
                  enabled         = true
                  label           = "grafana_alert"
                  labelValue      = "1"
                  searchNamespace = "ALL"
                }
                dashboards = {
                  enabled          = true
                  label            = "grafana_dashboard"
                  labelValue       = "1"
                  searchNamespace  = "ALL"
                  folderAnnotation = "grafana_folder"
                }
                datasources = {
                  defaultDatasourceEnabled = false
                }
              }

              additionalDataSources = [
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

              # Login redirects break if root_url doesn't match the host the
              # user hit via the private Gateway's wildcard listener.
              "grafana.ini" = {
                server = {
                  root_url = "https://grafana.${var.private_domain}"
                }
              }

              # Mounts every key from the alerting secrets as an env var so
              # provisioning files can reference them as $__env{KEY_NAME}.
              envFromSecret = kubernetes_secret.grafana_alerting_secrets.metadata[0].name

              # alerting provisioning is handled via grafana_alert=1 ConfigMaps
              # (see grafana-alerting.tf) — kept out of Helm values to avoid
              # the chart's tpl rendering breaking Grafana's {{ }} templates.

              # placeholder-end-of-grafana-values
              "end-of-grafana-values-placeholder" = {
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

                # ── Notification Policy ──────────────────────────────────────
                # Routes on the `channel` label every alert rule sets explicitly.
                # The default catch-all is `warning`; routes override per channel.
                "policies.yaml" = {
                  apiVersion = 1
                  policies = [
                    {
                      orgId          = 1
                      receiver       = "warning"
                      groupBy        = ["alertname", "namespace", "channel"]
                      groupWait      = "30s"
                      groupInterval  = "5m"
                      repeatInterval = "4h"
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
                      ]
                    },
                  ]
                }

                # ── Alert Rules ──────────────────────────────────────────────
                "rules.yaml" = {
                  apiVersion = 1
                  groups = [

                    # ── Group 1: Pod Health ──────────────────────────────────
                    {
                      orgId    = 1
                      name     = "pod-health"
                      folder   = "Platform Alerts"
                      interval = "1m"
                      rules = [

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
                                expr  = "kube_pod_container_status_restarts_total{namespace!~\"${local.critical_namespaces}\"} >= 3"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
                            description = "Container {{ $labels.container }} has restarted {{ $value }} times. Investigate with: kubectl logs {{ $labels.pod }} -n {{ $labels.namespace }} --previous"
                          }
                          labels = { severity = "error", channel = "error" }
                        },

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
                                expr  = "kube_pod_container_status_restarts_total{namespace=~\"${local.critical_namespaces}\"} >= 3"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "2m"
                          annotations = {
                            summary     = "CRITICAL: Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
                            description = "Container {{ $labels.container }} has restarted {{ $value }} times in a critical namespace. Immediate investigation required."
                          }
                          labels = { severity = "critical", channel = "critical" }
                        },

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
                                expr  = "(rate(container_cpu_usage_seconds_total{container!=\"\", container!=\"POD\", image!=\"\"}[5m]) / on(namespace, pod, container) kube_pod_container_resource_limits{resource=\"cpu\"}) > 0 and on(namespace, pod, container) kube_pod_container_resource_limits{resource=\"cpu\"} > 0"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0.80] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU at {{ $value | humanizePercentage }} of limit"
                            description = "Container {{ $labels.container }} is using {{ $value | humanizePercentage }} of its CPU limit. Consider scaling or raising the limit."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
                        },

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
                                expr  = "(container_memory_working_set_bytes{container!=\"\", container!=\"POD\", image!=\"\"} / on(namespace, pod, container) kube_pod_container_resource_limits{resource=\"memory\"}) > 0 and on(namespace, pod, container) kube_pod_container_resource_limits{resource=\"memory\"} > 0"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0.80] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} memory at {{ $value | humanizePercentage }} of limit"
                            description = "Container {{ $labels.container }} is using {{ $value | humanizePercentage }} of its memory limit. OOMKill risk if this continues."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
                        },

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
                                expr  = "sum by (namespace, pod, container) (rate(container_cpu_cfs_throttled_periods_total{container!=\"\", container!=\"POD\"}[1m])) / sum by (namespace, pod, container) (rate(container_cpu_cfs_periods_total{container!=\"\", container!=\"POD\"}[1m])) * 100"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [25] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU throttled {{ $value | printf \"%.1f\" }}% of periods"
                            description = "Container {{ $labels.container }} is being throttled >25% of CPU scheduling periods. Raise the CPU limit or reduce CPU request to allow more headroom."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
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
                                expr  = "sum by (namespace, pod, container) (rate(container_cpu_cfs_throttled_periods_total{container!=\"\", container!=\"POD\"}[1m])) / sum by (namespace, pod, container) (rate(container_cpu_cfs_periods_total{container!=\"\", container!=\"POD\"}[1m])) * 100"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [50] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU throttled {{ $value | printf \"%.1f\" }}% — probe failures likely"
                            description = "Container {{ $labels.container }} is being throttled >50% of CPU scheduling periods. Liveness/readiness probe failures and request timeouts are likely. Immediate CPU limit increase needed."
                          }
                          labels = { severity = "error", channel = "error" }
                        },

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
                                expr  = "sum by (namespace, pod, container) (rate(container_cpu_cfs_throttled_seconds_total{container!=\"\", container!=\"POD\"}[1m]))"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0.25] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} frozen {{ $value | printf \"%.2f\" }}s per second"
                            description = "Container {{ $labels.container }} is frozen >25% of wall-clock time due to CPU throttling. Consider increasing CPU limits."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
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
                                expr  = "sum by (namespace, pod, container) (rate(container_cpu_cfs_throttled_seconds_total{container!=\"\", container!=\"POD\"}[1m]))"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0.5] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} frozen {{ $value | printf \"%.2f\" }}s/s — barely running"
                            description = "Container {{ $labels.container }} is frozen >50% of wall-clock time. This pod is effectively non-functional. Raise CPU limits immediately."
                          }
                          labels = { severity = "error", channel = "error" }
                        },

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
                                expr  = "kube_pod_status_unschedulable == 1"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 600, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "10m"
                          annotations = {
                            summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} cannot be scheduled"
                            description = "Pod has been unschedulable for >10 minutes. Check node resources, taints, and affinities: kubectl describe pod {{ $labels.pod }} -n {{ $labels.namespace }}"
                          }
                          labels = { severity = "warning", channel = "warning" }
                        },

                      ]
                    },

                    # ── Group 2: Workload Availability ───────────────────────
                    {
                      orgId    = 1
                      name     = "workload-availability"
                      folder   = "Platform Alerts"
                      interval = "1m"
                      rules = [

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
                                expr  = "(kube_deployment_status_replicas_available{namespace!~\"${local.critical_namespaces}\"} == 0 and kube_deployment_spec_replicas{namespace!~\"${local.critical_namespaces}\"} > 0)"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "3m"
                          annotations = {
                            summary     = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has 0 available replicas"
                            description = "Deployment has 0 available replicas but spec requests > 0. Service may be down."
                          }
                          labels = { severity = "error", channel = "error" }
                        },

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
                                expr  = "(kube_statefulset_status_replicas_ready{namespace!~\"${local.critical_namespaces}\"} == 0 and kube_statefulset_replicas{namespace!~\"${local.critical_namespaces}\"} > 0)"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "3m"
                          annotations = {
                            summary     = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has 0 ready replicas"
                            description = "StatefulSet has 0 ready replicas but spec requests > 0. Stateful service may be down."
                          }
                          labels = { severity = "error", channel = "error" }
                        },

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
                                expr  = "(kube_deployment_status_replicas_available{namespace=~\"${local.critical_namespaces}\"} == 0 and kube_deployment_spec_replicas{namespace=~\"${local.critical_namespaces}\"} > 0)"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "1m"
                          annotations = {
                            summary     = "CRITICAL: Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has 0 replicas"
                            description = "Critical deployment is fully down. Immediate action required."
                          }
                          labels = { severity = "critical", channel = "critical" }
                        },

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
                                expr  = "(kube_statefulset_status_replicas_ready{namespace=~\"${local.critical_namespaces}\"} == 0 and kube_statefulset_replicas{namespace=~\"${local.critical_namespaces}\"} > 0)"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "1m"
                          annotations = {
                            summary     = "CRITICAL: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has 0 ready replicas"
                            description = "Critical stateful workload is fully down. Immediate action required."
                          }
                          labels = { severity = "critical", channel = "critical" }
                        },

                        # CNPG creates pods directly (not via a StatefulSet), so the
                        # StatefulSet metric above won't catch a downed CNPG cluster.
                        # This rule uses pod-count with an absent() fallback instead.
                        {
                          uid       = "cnpg-cluster-down"
                          title     = "CNPG Cluster Down"
                          condition = "B"
                          data = [
                            {
                              refId             = "A"
                              datasourceUid     = "prometheus-main"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                expr  = "(count by(namespace) (kube_pod_status_ready{namespace=\"postgres\", condition=\"true\"}) == 0) or (absent(kube_pod_status_ready{namespace=\"postgres\", condition=\"true\"}))"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "Alerting"
                          execErrState = "Error"
                          "for"        = "1m"
                          annotations = {
                            summary     = "CRITICAL: CNPG cluster in namespace postgres has no ready pods"
                            description = "The CloudNativePG cluster has 0 ready pods. Database connectivity is lost. Check: kubectl get cluster -n postgres"
                          }
                          labels = { severity = "critical", channel = "critical" }
                        },

                      ]
                    },

                    # ── Group 3: Node & Storage Health ───────────────────────
                    {
                      orgId    = 1
                      name     = "node-and-storage"
                      folder   = "Platform Alerts"
                      interval = "1m"
                      rules = [

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
                                expr  = "(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [85] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "5m"
                          annotations = {
                            summary     = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is {{ $value | printf \"%.1f\" }}% full"
                            description = "Volume is above 85% capacity. Expand the PVC or clean up data to avoid pod failures."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
                        },

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
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [75] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "10m"
                          annotations = {
                            summary     = "Node {{ $labels.node }} CPU at {{ $value | printf \"%.1f\" }}%"
                            description = "Node CPU has been above 75% for 10+ minutes. Consider adding nodes or moving workloads."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
                        },

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
                                expr  = "((node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes) * 100"
                                refId = "A"
                              }
                            },
                            {
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [75] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "10m"
                          annotations = {
                            summary     = "Node {{ $labels.instance }} memory at {{ $value | printf \"%.1f\" }}%"
                            description = "Node memory has been above 75% for 10+ minutes. OOMKill risk for pods without memory limits."
                          }
                          labels = { severity = "warning", channel = "scale-workloads" }
                        },

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
                              refId             = "B"
                              datasourceUid     = "__expr__"
                              relativeTimeRange = { from = 300, to = 0 }
                              model = {
                                type       = "threshold"
                                refId      = "B"
                                conditions = [{ evaluator = { type = "gt", params = [0] }, query = { params = ["A"] } }]
                              }
                            },
                          ]
                          noDataState  = "NoData"
                          execErrState = "Error"
                          "for"        = "1m"
                          annotations = {
                            summary     = "Node {{ $labels.node }} is under MemoryPressure"
                            description = "Kubelet has set MemoryPressure=True on this node. Pod evictions may already be in progress. Check: kubectl describe node {{ $labels.node }}"
                          }
                          labels = { severity = "warning", channel = "warning" }
                        },

                      ]
                    },

                  ]
                }

              }
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.grafana.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  depends_on = [
    kubernetes_secret.grafana_admin,
    kubernetes_secret.grafana_alerting_secrets,
  ]
}

# Loki
resource "kubernetes_manifest" "loki" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "loki"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "2"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://grafana.github.io/helm-charts"
        chart          = "loki"
        targetRevision = var.loki_chart_version
        helm = {
          values = yamlencode({
            deploymentMode = "SingleBinary"

            loki = {
              auth_enabled = false

              schemaConfig = {
                configs = [
                  {
                    from         = "2024-01-01"
                    store        = "tsdb"
                    object_store = "gcs"
                    schema       = "v13"
                    index = {
                      prefix = "loki_index_"
                      period = "24h"
                    }
                  },
                ]
              }

              storage = {
                type = "gcs"
                bucketNames = {
                  chunks = var.loki_gcs_bucket_name
                  ruler  = var.loki_gcs_bucket_name
                  admin  = var.loki_gcs_bucket_name
                }
              }

              limits_config = {
                retention_period = "168h" // 7 days
              }

              compactor = {
                working_directory             = "/var/loki/compactor"
                retention_enabled             = true
                retention_delete_delay        = "2h"
                retention_delete_worker_count = 150
                delete_request_store          = "gcs"
              }
            }

            singleBinary = {
              replicas = 2
              persistence = {
                enabled      = true
                size         = "2Gi"
                storageClass = "standard"
              }
            }

            read    = { replicas = 0 }
            write   = { replicas = 0 }
            backend = { replicas = 0 }

            chunksCache  = { enabled = false }
            resultsCache = { enabled = false }

            gateway = {
              enabled  = true
              replicas = 1
              basicAuth = {
                enabled = false
              }
            }

            serviceAccount = {
              create = true
              name   = "loki"
              annotations = {
                "iam.gke.io/gcp-service-account" = var.loki_gcs_sa_email
              }
            }

            test       = { enabled = false }
            lokiCanary = { enabled = false }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.logging.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  depends_on = [kubernetes_namespace.logging]
}

# Alloy
resource "kubernetes_manifest" "alloy" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "alloy"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "4"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://grafana.github.io/helm-charts"
        chart          = "alloy"
        targetRevision = var.alloy_chart_version
        helm = {
          values = yamlencode({
            controller = {
              type = "daemonset"
              podLabels = {
                "istio.io/dataplane-mode" = "none"
              }
            }

            alloy = {
              mounts = {
                # varlog = true
                varlog = false
              }

              # Expose the node name to the Alloy config — the discovery.kubernetes
              # field selector needs `spec.nodeName=<node>`, but HOSTNAME inside the
              # pod is the pod name. Without this, Alloy scrapes zero pod logs.
              extraEnv = [
                {
                  name = "NODE_NAME"
                  valueFrom = {
                    fieldRef = {
                      fieldPath = "spec.nodeName"
                    }
                  }
                },
              ]

              configMap = {
                content = file("${path.module}/config/alloy-config.alloy")
              }
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.logging.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  depends_on = [kubernetes_manifest.loki]
}

# Tempo
resource "kubernetes_manifest" "tempo" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "tempo"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "2"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://grafana-community.github.io/helm-charts"
        chart          = "tempo"
        targetRevision = var.tempo_chart_version
        helm = {
          values = yamlencode({
            tempo = {
              storage = {
                trace = {
                  backend = "gcs"
                  gcs = {
                    bucket_name = var.tempo_gcs_bucket_name
                  }
                }
              }

              retention = "168h" // 7 days

              receivers = {
                otlp = {
                  protocols = {
                    grpc = {
                      endpoint = "0.0.0.0:4317"
                    }
                    http = {
                      endpoint = "0.0.0.0:4318"
                    }
                  }
                }
              }

              metricsGenerator = {
                enabled     = true
                remoteWrite = [{ url = "http://prometheus-operated.monitoring.svc:9090/api/v1/write" }]
              }

              serviceGraph = {
                enabled = true
              }
            }

            persistence = {
              enabled          = true
              size             = "2Gi"
              storageClassName = "standard"
            }

            serviceAccount = {
              create = true
              name   = "tempo"
              annotations = {
                "iam.gke.io/gcp-service-account" = var.tempo_gcs_sa_email
              }
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.tracing.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  depends_on = [kubernetes_namespace.tracing]
}

# Kiali
resource "kubernetes_manifest" "kiali" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "kiali"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "2"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://kiali.org/helm-charts"
        chart          = "kiali-operator"
        targetRevision = var.kiali_chart_version
        helm = {
          values = yamlencode(
            {
              cr = {
                create    = true
                namespace = kubernetes_namespace.tracing.metadata[0].name
                spec = {
                  auth = {
                    strategy = "anonymous"
                  }
                  deployment = {
                    accessible_namespaces = ["**"]
                    cluster_wide_access   = true
                  }
                  external_services = {
                    prometheus = {
                      url = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
                    }
                    grafana = {
                      enabled        = true
                      in_cluster_url = "http://grafana.grafana.svc.cluster.local:80"
                    }
                    tracing = {
                      enabled      = true
                      provider     = "jaeger"
                      internal_url = "http://jaeger-query.tracing.svc.cluster.local:16685"
                      use_grpc     = true
                    }
                  }
                }
              }
            }
          )
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.tracing.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-CMD
      # 1. Strip ArgoCD finalizer from the Application so ArgoCD cascade-deletes immediately
      kubectl patch application ${self.manifest.metadata.name} \
        -n ${self.manifest.metadata.namespace} \
        --type=merge -p '{"metadata":{"finalizers":[]}}' || true

      # 2. Strip kiali.io/finalizer from all Kiali CRs in the destination namespace.
      kubectl get kialis.kiali.io \
        -n ${self.manifest.spec.destination.namespace} \
        -o name 2>/dev/null | \
        xargs -I {} kubectl patch {} \
          -n ${self.manifest.spec.destination.namespace} \
          --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
    CMD
  }

  depends_on = [kubernetes_namespace.tracing]
}

# Jaeger
resource "kubernetes_manifest" "jaeger" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "jaeger"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "2"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://jaegertracing.github.io/helm-charts"
        chart          = "jaeger"
        targetRevision = var.jaeger_chart_version
        helm = {
          values = yamlencode({
            provisionDataStore = {
              elasticsearch = true
            }
            allInOne = {
              enabled = false
            }
            storage = {
              type = "elasticsearch"
            }
            elasticsearch = {
              master = {
                masterOnly   = false
                replicaCount = 1
              }
              data = {
                replicaCount = 0
              }
              coordinating = {
                replicaCount = 0
              }
              ingest = {
                replicaCount = 0
              }
            }
            collector = {
              enabled = true
              service = {
                otlp = {
                  grpc = {
                    name = "otlp-grpc"
                    port = 4317
                  }
                  http = {
                    name = "otlp-http"
                    port = 4318
                  }
                }
              }
            }
            query = {
              enabled = true
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.tracing.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  depends_on = [kubernetes_namespace.tracing]
}

# Mesh-wide Telemetry CR
resource "kubernetes_manifest" "istio_telemetry" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "istio-telemetry"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "3"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "terraform/kubernetes/manifests/telemetry"
        helm = {
          values = yamlencode({
            tracing = {
              providerName             = "tempo-otel"
              randomSamplingPercentage = var.tracing_sampling_percentage
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "istio-system"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [kubernetes_manifest.tempo]
}

# Istio monitors — PodMonitors + ServiceMonitor pointing Prometheus at sidecar,
# istiod, Gateway API gateway, and ztunnel metrics endpoints.
resource "kubernetes_manifest" "istio_monitors" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "istio-monitors"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "4"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "terraform/kubernetes/manifests/istio-monitors"
        helm = {
          values = yamlencode({
            scrapeInterval = "15s"
            gateways = {
              namespaces = ["istio-ingress", "istio-ingress-internal"]
              names      = ["public", "private"]
            }
            istiodNamespace  = "istio-system"
            ztunnelNamespace = "istio-system"
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.monitoring.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [kubernetes_manifest.kube_prometheus_stack]
}

# Kubernetes Event Exporter
resource "kubernetes_manifest" "kubernetes_event_exporter" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "kubernetes-event-exporter"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "4"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "registry-1.docker.io/bitnamicharts"
        chart          = "kubernetes-event-exporter"
        targetRevision = var.kubernetes_event_exporter_chart_version
        helm = {
          values = yamlencode({
            image = {
              repository = "bitnamilegacy/kubernetes-event-exporter"
            }

            podLabels = {
              app = "kubernetes-event-exporter"
            }

            config = {
              clusterName        = var.cluster_name
              leaderElection     = {}
              logFormat          = "pretty"
              logLevel           = "debug"
              maxEventAgeSeconds = 3600
              metricsNamePrefix  = "event_exporter_"

              route = {
                routes = [
                  {
                    match = [
                      { receiver = "dump" },
                      { receiver = "loki" },
                    ]
                  },
                ]
              }

              receivers = [
                {
                  name = "dump"
                  file = {
                    path = "/dev/stdout"
                    layout = {
                      message   = "{{ .Message }}"
                      reason    = "{{ .Reason }}"
                      type      = "{{ .Type }}"
                      count     = "{{ .Count }}"
                      namespace = "{{ .InvolvedObject.Namespace }}"
                      kind      = "{{ .InvolvedObject.Kind }}"
                      name      = "{{ .InvolvedObject.Name }}"
                      component = "{{ .Source.Component }}"
                      host      = "{{ .Source.Host }}"
                    }
                  }
                },
                {
                  name = "loki"
                  loki = {
                    url = "http://loki-gateway.logging.svc/loki/api/v1/push"
                    streamLabels = {
                      container = "kubernetes-event-exporter"
                      source    = "kubernetes-event-exporter"
                    }
                    layout = {
                      message      = "{{ .Message }}"
                      reason       = "{{ .Reason }}"
                      type         = "{{ .Type }}"
                      count        = "{{ .Count }}"
                      cluster_name = "{{ .ClusterName }}"

                      # InvolvedObject (old-style) & Regarding (new-style)
                      namespace = "{{ .InvolvedObject.Namespace }}"
                      kind      = "{{ .InvolvedObject.Kind }}"
                      name      = "{{ .InvolvedObject.Name }}"

                      # Source component: old-style uses Source.Component, new-style uses
                      # ReportingComponent directly on the event
                      component           = "{{ .Source.Component }}"
                      host                = "{{ .Source.Host }}"

                      # Timestamps: old-style uses FirstTimestamp/LastTimestamp,
                      # new-style uses EventTime
                      first_time = "{{ .FirstTimestamp }}"
                      last_time  = "{{ .LastTimestamp }}"
                      event_time = "{{ .EventTime }}"
                    }
                  }
                },
              ]
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.events.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.loki,
    kubernetes_secret.bitnami_charts_oci_repo,
  ]
}

# * SECRETS STACK

# External Secrets Operator
resource "kubernetes_manifest" "external_secrets" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "external-secrets"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "0"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://charts.external-secrets.io"
        chart          = "external-secrets"
        targetRevision = var.external_secrets_chart_version
        helm = {
          values = yamlencode({
            installCRDs = true
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.external_secrets.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

# * MICROSERVICES STACK

# Users microservice
resource "kubernetes_manifest" "users_microservice" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "users-microservice"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "5"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      sources = [
        {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "helm/custom-charts/microservice"
          helm = {
            values = yamlencode({
              useDeployment = true
              replicas      = 2

              containers = [
                {
                  name            = "users"
                  image           = local.users_microservice_image
                  imagePullPolicy = "Always"
                  configMapRef    = [kubernetes_config_map.users_microservice.metadata[0].name]
                  secretRef       = [kubernetes_secret.users_microservice_db.metadata[0].name]
                  resources = {
                    requests = {
                      cpu    = "250m"
                      memory = "256Mi"
                    }
                    limits = {
                      cpu    = "1000m"
                      memory = "3Gi"
                    }
                  }
                  otherSpecs = {
                    readinessProbe = {
                      httpGet = {
                        path = "/health"
                        port = 9090
                      }
                      initialDelaySeconds = 10
                      periodSeconds       = 15
                      timeoutSeconds      = 10
                      failureThreshold    = 3
                    }
                    livenessProbe = {
                      httpGet = {
                        path = "/health"
                        port = 9090
                      }
                      initialDelaySeconds = 30
                      periodSeconds       = 30
                      timeoutSeconds      = 10
                      failureThreshold    = 5
                    }
                  }
                },
              ]

              service = {
                enabled    = true
                type       = "ClusterIP"
                port       = 80
                targetPort = 9090
              }

              hpa = {
                enabled                        = true
                minReplicas                    = 2
                maxReplicas                    = 12
                targetCPUUtilizationPercentage = 75
              }
            })
          }
        },
        # {
        #   repoURL        = var.repo_url
        #   targetRevision = var.target_revision
        #   path           = "terraform/kubernetes/manifests/users"
        #   helm = {
        #     values = yamlencode({
        #       service = {
        #         name         = "users-microservice-service"
        #         externalHost = "users.internal.pe.onukwilip.xyz"
        #       }
        #       gateways = ["mesh", "istio-ingress-internal/private"]
        #       destinationRule = {
        #         connectionPool = {
        #           enabled = false
        #         }
        #       }
        #     })
        #   }
        # },
      ]
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.users.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.postgres_cluster,
    kubernetes_config_map.users_microservice,
    kubernetes_secret.users_microservice_db,
  ]
}

# Store UI
resource "kubernetes_manifest" "store_ui" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "store-ui"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "5"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "helm/custom-charts/microservice"
        helm = {
          values = yamlencode({
            useDeployment = true
            replicas      = 1

            containers = [
              {
                name            = "store-ui"
                image           = local.store_ui_image
                imagePullPolicy = "IfNotPresent"
              },
            ]

            service = {
              enabled    = true
              type       = "ClusterIP"
              port       = 80
              targetPort = 80
            }
          })
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.store_ui.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [kubernetes_namespace.store_ui]
}

# * LOAD TESTING STACK

resource "kubernetes_manifest" "k6_operator" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "k6-operator"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "0"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://grafana.github.io/helm-charts"
        chart          = "k6-operator"
        targetRevision = var.k6_operator_chart_version
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.load_testing.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true", "ServerSideDiff=true"]
      }
    }
  }
}
