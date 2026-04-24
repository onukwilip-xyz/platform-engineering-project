resource "kubernetes_manifest" "trust_manager_bundle" {
  manifest = {
    apiVersion = "trust.cert-manager.io/v1alpha1"
    kind       = "Bundle"
    metadata = {
      name = "internal-ca-bundle"
    }
    spec = {
      sources = [
        {
          secret = {
            name = kubernetes_secret.ca.metadata[0].name
            key  = "tls.crt"
          }
        },
        {
          useDefaultCAs = true
        },
      ]
      target = {
        secret = {
          key = "ca.crt"
        }
        namespaceSelector = {
          matchLabels = {
            "trust.cert-manager.io/internal-ca" = "true"
          }
        }
      }
    }
  }
}
