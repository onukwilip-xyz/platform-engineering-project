resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      istio-injection = "enabled"
    }
  }
}