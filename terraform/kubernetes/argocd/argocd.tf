resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }

      configs = {
        params = {
          "server.insecure" = "true"
        }
        cm = {
          "resource.customizations.ignoreDifferences.apps_Deployment" = yamlencode({
            managedFieldsManagers = ["kube-controller-manager"]
          })
        }
      }

      controller = {
        replicas = 1
      }

      server = {
        replicas = 2
        autoscaling = {
          enabled = false
        }
        ingress = {
          enabled = false
        }
      }

      repoServer = {
        replicas = 2
        autoscaling = {
          enabled = false
        }
      }

      applicationSet = {
        replicas = 2
        autoscaling = {
          enabled = false
        }
        ingress = {
          enabled = false
        }
      }

      "redis-ha" = {
        enabled = true
        redis = {
          podAnnotations = {
            "sidecar.istio.io/inject" = false
          }
        }
        haproxy = {
          podAnnotations = {
            "sidecar.istio.io/inject" = false
          }
        }
      }
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [kubernetes_namespace.argocd]
}
