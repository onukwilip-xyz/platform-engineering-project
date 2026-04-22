resource "kubernetes_manifest" "argocd_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name        = var.private_gateway_name
          namespace   = var.private_gateway_namespace
          sectionName = "https"
        }
      ]
      hostnames = ["argocd.${var.private_domain}"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}