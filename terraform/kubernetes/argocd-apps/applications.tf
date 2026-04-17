resource "kubernetes_manifest" "cnpg_operator" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "cnpg-operator"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
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
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true"]
      }
    }
  }

  depends_on = [kubernetes_manifest.cnpg_operator]
}