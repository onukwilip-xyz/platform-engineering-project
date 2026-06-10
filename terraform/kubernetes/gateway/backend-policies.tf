resource "kubernetes_manifest" "public_istio_gateway_backend_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "public-istio-gateway-backend-policy"
      namespace = kubernetes_namespace.istio_ingress.metadata[0].name
    }
    spec = {
      default = {
        timeoutSec = 30
        logging = {
          enabled    = true
          sampleRate = 100000
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
