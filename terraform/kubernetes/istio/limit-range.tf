resource "kubernetes_limit_range" "istio_system" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.istio_system.metadata[0].name
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
