resource "kubernetes_manifest" "public_istio_health_check_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "HealthCheckPolicy"
    metadata = {
      name      = "public-istio-healthcheck"
      namespace = kubernetes_namespace.istio_ingress.metadata[0].name
    }
    spec = {
      default = {
        config = {
          type = "HTTP"
          httpHealthCheck = {
            port        = 15021
            requestPath = "/healthz/ready"
          }
        }
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = "${kubernetes_manifest.gateway_public.manifest.metadata.name}-istio"
      }
    }
  }
}