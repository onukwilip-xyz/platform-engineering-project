# Placeholder admin credentials for Grafana. Replaces with an ESO-managed
# ExternalSecret once the External Secrets Operator lands in the cluster.
resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  type = "Opaque"

  data = {
    "admin-user"     = "admin"
    "admin-password" = random_password.grafana_admin.result
  }
}