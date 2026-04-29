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

              # The chart's default auto-datasource targets this release's own
              # (disabled) Prometheus. Point at the monitoring release instead.
              sidecar = {
                datasources = {
                  defaultDatasourceEnabled = false
                }
              }

              additionalDataSources = [
                {
                  name      = "Prometheus"
                  type      = "prometheus"
                  url       = "http://prometheus-operated.monitoring.svc:9090"
                  access    = "proxy"
                  isDefault = true
                },
                {
                  name   = "Loki"
                  type   = "loki"
                  url    = "http://loki-gateway.logging.svc"
                  access = "proxy"
                },
                {
                  name   = "Tempo"
                  type   = "tempo"
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

  depends_on = [kubernetes_secret.grafana_admin]
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
                varlog = true
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
                content = file("${path.module}/alloy-config.alloy")
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
                      cpu    = "1200m"
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
                minReplicas                    = 8
                maxReplicas                    = 12
                targetCPUUtilizationPercentage = 75
              }
            })
          }
        },
        {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "terraform/kubernetes/manifests/users"
          helm = {
            values = yamlencode({
              service = {
                name         = "users-microservice-service"
                externalHost = "users.internal.pe.onukwilip.xyz"
              }
              gateways = ["mesh", "istio-ingress-internal/private"]
              destinationRule = {
                connectionPool = {
                  enabled = false
                }
              }
            })
          }
        },
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
