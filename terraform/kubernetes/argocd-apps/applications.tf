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
          values = yamlencode({
            priorityClassName = "medium-priority"
            config = {
              clusterWide = true
            }
            resources = {
              requests = { cpu = "100m", memory = "100Mi" }
              limits   = { cpu = "200m", memory = "200Mi" }
            }
          })
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
        "argocd.argoproj.io/sync-wave" = "2"
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
            postgresClusterStatusServiceName = local.postgres_cluster_status_service_name
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
        "argocd.argoproj.io/sync-wave"       = "1"
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

            prometheusOperator = {
              priorityClassName = "medium-priority"
              resources = {
                requests = { cpu = "50m", memory = "64Mi" }
                limits   = { cpu = "200m", memory = "256Mi" }
              }
            }

            prometheus = {
              prometheusSpec = {
                priorityClassName = "medium-priority"
                # `Nil…SelectorNilUsesHelmValues = false` lets Prometheus discover
                # ServiceMonitors / PodMonitors / PrometheusRules / Probes created
                # in other namespaces (grafana, logging, tracing, microservices…).
                serviceMonitorSelectorNilUsesHelmValues = false
                podMonitorSelectorNilUsesHelmValues     = false
                ruleSelectorNilUsesHelmValues           = false
                probeSelectorNilUsesHelmValues          = false
                enableRemoteWriteReceiver               = true
                retention                               = "7d"

                resources = {
                  requests = { cpu = "200m", memory = "512Mi" }
                  limits   = { cpu = "1000m", memory = "2Gi" }
                }

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

            "kube-state-metrics" = {
              resources = {
                requests = { cpu = "20m", memory = "64Mi" }
                limits   = { cpu = "100m", memory = "128Mi" }
              }
            }

            alertmanager = {
              alertmanagerSpec = {
                resources = {
                  requests = { cpu = "50m", memory = "128Mi" }
                  limits   = { cpu = "200m", memory = "256Mi" }
                }
              }
            }

            # node-exporter runs with hostNetwork=true; ambient CNI can't redirect
            # hostNetwork pods, so opt the DaemonSet out of the mesh.
            "prometheus-node-exporter" = {
              podLabels = {
                "istio.io/dataplane-mode" = "none"
              }
              resources = {
                requests = { cpu = "10m", memory = "32Mi" }
                limits   = { cpu = "100m", memory = "64Mi" }
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
              priorityClassName        = "medium-priority"

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

              envFromSecrets = [
                {
                  name     = kubernetes_secret.grafana_alerting_secrets.metadata[0].name
                  optional = false
                },
                {
                  name     = kubernetes_secret.grafana_pagerduty.metadata[0].name
                  optional = false
                }
              ]


              resources = {
                requests = { cpu = "100m", memory = "128Mi" }
                limits   = { cpu = "300m", memory = "256Mi" }
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
    kubernetes_config_map.grafana_alerting_contactpoints,
    kubernetes_config_map.grafana_alerting_policies,
    kubernetes_config_map.grafana_alerting_rules,
  ]
}

# Sloth
resource "kubernetes_manifest" "sloth" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "sloth"
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
        repoURL        = "https://slok.github.io/sloth"
        chart          = "sloth"
        targetRevision = var.sloth_chart_version
        helm = {
          values = yamlencode({
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
        namespace = kubernetes_namespace.monitoring.metadata[0].name
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

  depends_on = [kubernetes_manifest.kube_prometheus_stack]
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
              resources = {
                requests = { cpu = "250m", memory = "512Mi" }
                limits   = { cpu = "500m", memory = "1Gi" }
              }
            }

            gateway = {
              enabled  = true
              replicas = 1
              basicAuth = {
                enabled = false
              }
              resources = {
                requests = { cpu = "50m", memory = "64Mi" }
                limits   = { cpu = "100m", memory = "128Mi" }
              }
            }

            read    = { replicas = 0 }
            write   = { replicas = 0 }
            backend = { replicas = 0 }

            chunksCache  = { enabled = false }
            resultsCache = { enabled = false }

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

              resources = {
                requests = { cpu = "500m", memory = "1Gi" }
                limits   = { cpu = "1000m", memory = "2Gi" }
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
              resources = {
                requests = { cpu = "10m", memory = "64Mi" }
                limits   = { cpu = "100m", memory = "256Mi" }
              }

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
                    resources = {
                      requests = { cpu = "100m", memory = "128Mi" }
                      limits   = { cpu = "200m", memory = "256Mi" }
                    }
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
                    layout = {
                      message      = "{{ .Message }}"
                      reason       = "{{ .Reason }}"
                      type         = "{{ .Type }}"
                      count        = "{{ .Count }}"
                      cluster_name = "{{ .ClusterName }}"

                      namespace = "{{ .InvolvedObject.Namespace }}"
                      kind      = "{{ .InvolvedObject.Kind }}"
                      name      = "{{ .InvolvedObject.Name }}"

                      component = "{{ .Source.Component }}"
                      host      = "{{ .Source.Host }}"

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

# Gatus
resource "kubernetes_manifest" "gatus" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "gatus"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave"       = "5"
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://twin.github.io/helm-charts"
        chart          = "gatus"
        targetRevision = var.gatus_chart_version
        helm = {
          values = yamlencode({
            replicaCount = 1

            podAnnotations = {
              "istio.io/dataplane-mode" = "ambient"
            }

            extraVolumeMounts = [
              {
                name           = "internal-ca"
                mountPath      = "/certs/internal-ca"
                readOnly       = true
                existingSecret = "internal-ca-bundle"
              }
            ]

            resources = {
              requests = {
                cpu    = "50m"
                memory = "64Mi"
              }
              limits = {
                cpu    = "200m"
                memory = "128Mi"
              }
            }

            serviceMonitor = {
              enabled   = true
              namespace = "monitoring"
              interval  = "60s"
              labels = {
                # Must match your Prometheus operator's serviceMonitorSelector label
                release = "kube-prometheus-stack"
              }
            }

            service = {
              port = 8080
            }

            ingress = {
              enabled = false
            }

            config = {
              metrics = true

              endpoints = [
                {
                  name     = "users-microservice"
                  group    = "internal-services"
                  url      = "http://${local.users_microservice}-service.${kubernetes_namespace.users.metadata[0].name}.svc.cluster.local:80/health"
                  interval = "30s"
                  conditions = [
                    "[STATUS] == 200"
                  ]
                },

                {
                  name     = "store-ui-public"
                  group    = "public"
                  url      = "https://store.pe.onukwilip.me"
                  interval = "1m"
                  conditions = [
                    "[STATUS] == 200"
                  ]
                },

                {
                  name     = "public-istio-gateway"
                  group    = "infrastructure"
                  url      = "http://${var.public_gateway_name}-istio.${var.public_gateway_namespace}.svc.cluster.local:15021/healthz/ready"
                  interval = "30s"
                  conditions = [
                    "[STATUS] == 200"
                  ]
                },

                {
                  name     = "private-istio-gateway"
                  group    = "infrastructure"
                  url      = "http://${var.private_gateway_name}-istio.${var.private_gateway_namespace}.svc.cluster.local:15021/healthz/ready"
                  interval = "30s"
                  conditions = [
                    "[STATUS] == 200"
                  ]
                },

                {
                  name     = "postgres-cnpg"
                  group    = "databases"
                  url      = "https://${local.postgres_cluster_status_service_name}.${kubernetes_namespace.postgres.metadata[0].name}.svc.cluster.local:8000/healthz"
                  interval = "30s"
                  conditions = [
                    "[STATUS] == 200"
                  ],
                  client = {
                    tls = {
                      ca       = "/certs/internal-ca/ca.crt"
                      insecure = false
                    }
                  }
                },

                {
                  name     = "pgbouncer"
                  group    = "databases"
                  url      = "tcp://postgres-pooler-rw.${kubernetes_namespace.postgres.metadata[0].name}.svc.cluster.local:5432"
                  interval = "30s"
                  conditions = [
                    "[CONNECTED] == true"
                  ]
                }

              ]
            }

            env = {
              SSL_CERT_FILE = "/certs/internal-ca/ca.crt"
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
          "ServerSideDiff=true"
        ]
      }
    }
  }
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
            resources = {
              requests = { cpu = "10m", memory = "64Mi" }
              limits   = { cpu = "100m", memory = "128Mi" }
            }
            webhook = {
              resources = {
                requests = { cpu = "10m", memory = "32Mi" }
                limits   = { cpu = "50m", memory = "64Mi" }
              }
            }
            certController = {
              resources = {
                requests = { cpu = "10m", memory = "32Mi" }
                limits   = { cpu = "50m", memory = "64Mi" }
              }
            }
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
      name      = local.users_microservice
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
                      # cpu    = "1000m"
                      cpu = "500m"
                      # memory = "3Gi"
                      memory = "500Mi"
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
                minReplicas                    = 1
                maxReplicas                    = 1
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
                name         = "${local.users_microservice}-service"
                externalHost = "users.internal.pe.onukwilip.xyz"
              }
              gateways = ["mesh", "istio-ingress-internal/private"]
              destinationRule = {
                connectionPool = {
                  enabled = false
                }
              }
              slo = { enabled = true }
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
        syncOptions = [
          "CreateNamespace=false",
          "SkipDryRunOnMissingResource=true",
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "10s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.sloth,
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
      sources = [
        {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "helm/custom-charts/microservice"
          helm = {
            values = yamlencode({
              useDeployment = true

              containers = [
                {
                  name            = "store-ui"
                  image           = local.store_ui_image
                  imagePullPolicy = "IfNotPresent"
                  resources = {
                    requests = {
                      cpu    = "20m"
                      memory = "50Mi"
                    }
                    limits = {
                      cpu    = "20m"
                      memory = "50Mi"
                    }
                  }
                },
              ]

              service = {
                enabled    = true
                type       = "ClusterIP"
                port       = 80
                targetPort = 80
              }

              hpa = {
                enabled                        = true
                minReplicas                    = 1
                maxReplicas                    = 1
                targetCPUUtilizationPercentage = 75
              }
            })
          }
        },
        {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "terraform/kubernetes/manifests/store-ui"
          helm = {
            values = yamlencode({
              slo = { enabled = true }
            })
          }
        },
      ]
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.store_ui.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=false",
          "SkipDryRunOnMissingResource=true",
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "10s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.sloth,
    kubernetes_namespace.store_ui,
  ]
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
