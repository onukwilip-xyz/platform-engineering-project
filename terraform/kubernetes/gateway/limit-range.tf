resource "kubernetes_limit_range" "gke_ingress" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.gke_ingress.metadata[0].name
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

resource "kubernetes_limit_range" "istio_ingress" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.istio_ingress.metadata[0].name
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

resource "kubernetes_limit_range" "istio_ingress_internal" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.istio_ingress_internal.metadata[0].name
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
