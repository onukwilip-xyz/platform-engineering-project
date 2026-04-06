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

  depends_on = [helm_release.cert_manager, kubernetes_secret.ca]
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

  depends_on = [
    helm_release.cert_manager,
    google_service_account_iam_member.cert_manager_workload_identity,
  ]
}