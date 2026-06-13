resource "kubernetes_limit_range" "argocd" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}
