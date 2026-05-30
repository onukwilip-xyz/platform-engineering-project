resource "null_resource" "argocd_crds" {
  triggers = {
    chart_version = var.argocd_chart_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add argo https://argoproj.github.io/argo-helm --force-update
      helm template argocd argo/argo-cd \
        --version ${self.triggers.chart_version} \
        --namespace argocd \
        --include-crds \
        --no-hooks \
      | python3 -c 'import sys; docs=sys.stdin.read().split("\n---"); crds=[d for d in docs if "kind: CustomResourceDefinition" in d]; print("\n---".join(crds))' \
      | kubectl apply --server-side --force-conflicts -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      helm template argocd argo/argo-cd \
        --version ${self.triggers.chart_version} \
        --namespace argocd \
        --include-crds \
        --no-hooks \
      | python3 -c 'import sys; docs=sys.stdin.read().split("\n---"); crds=[d for d in docs if "kind: CustomResourceDefinition" in d]; print("\n---".join(crds))' \
      | kubectl delete --ignore-not-found=true -f -
    EOT
  }

  depends_on = [kubernetes_namespace.argocd]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      crds = {
        install = false
      }

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
            "istio.io/dataplane-mode" = "none"
          }
        }
        haproxy = {
          podAnnotations = {
            "istio.io/dataplane-mode" = "none"
          }
        }
      }
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [null_resource.argocd_crds, kubernetes_namespace.argocd]
}
