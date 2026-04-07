# Both ClusterIssuers are safe to plan here because this module is a separate
# Terragrunt unit that only runs after cert-manager/ has been fully applied —
# meaning the ClusterIssuer CRD is already registered in the live cluster.

resource "kubernetes_manifest" "cluster_issuer_internal" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.internal_cluster_issuer_name
    }
    spec = {
      ca = {
        secretName = kubernetes_secret.ca.metadata[0].name
      }
    }
  }

  depends_on = [kubernetes_secret.ca]
}

resource "kubernetes_manifest" "cluster_issuer_public" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.public_cluster_issuer_name
    }
    spec = {
      acme = {
        server = var.acme_server
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-account-key"
        }
        solvers = [
          {
            dns01 = {
              cloudDNS = {
                project = var.dns_project_id
              }
            }
          }
        ]
      }
    }
  }
}