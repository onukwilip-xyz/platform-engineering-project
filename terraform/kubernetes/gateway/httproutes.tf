resource "kubernetes_manifest" "gke_to_istio_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "gke-to-public-istio"
      namespace = kubernetes_namespace.istio_ingress.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name        = kubernetes_manifest.gateway_gke.manifest.metadata.name
          namespace   = kubernetes_namespace.gke_ingress.metadata[0].name
          sectionName = "https"
        }
      ]
      hostnames = ["*.${var.public_domain}"]
      rules = [
        {
          backendRefs = [
            {
              name      = "${kubernetes_manifest.gateway_public.manifest.metadata.name}-istio"
              namespace = kubernetes_namespace.istio_ingress.metadata[0].name
              port      = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.gateway_gke,
    kubernetes_manifest.gateway_public,
  ]
}