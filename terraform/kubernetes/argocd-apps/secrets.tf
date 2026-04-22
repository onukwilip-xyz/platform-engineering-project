# * GRAFANA CREDENTIALS

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

# * USERS MICROSERVICE DB CREDENTIALS

resource "random_password" "users_db" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "users_db_credentials" {
  metadata {
    name      = "users-app-credentials"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = local.users_db_username
    password = random_password.users_db.result
  }
}

resource "kubernetes_secret" "users_microservice_db" {
  metadata {
    name      = "users-db"
    namespace = kubernetes_namespace.users.metadata[0].name
  }

  type = "Opaque"

  data = {
    DATABASE_URL = "postgresql+asyncpg://${local.users_db_username}:${random_password.users_db.result}@postgres-cluster-rw.postgres.svc:5432/${local.users_db_name}"
  }
}

# * ARGOCD OCI REPO REGISTRATIONS

# Kubernetes Event Exporter
resource "kubernetes_secret" "bitnami_charts_oci_repo" {
  metadata {
    name      = "bitnami-charts-oci"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    name      = "bitnami-charts-oci"
    url       = "registry-1.docker.io/bitnamicharts"
    type      = "helm"
    enableOCI = "true"
  }
}