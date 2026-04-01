locals {
  secret_labels = merge(var.labels, {
    purpose     = "vpn-credentials"
    gcp-product = "secret-manager"
  })
}

resource "google_secret_manager_secret" "netbird_pat" {
  secret_id = var.netbird_pat_secret_id
  project   = var.project_id

  labels = merge(local.secret_labels, { usage = "netbird-pat" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "netbird_admin_password" {
  secret_id = var.netbird_admin_password_secret_id
  project   = var.project_id

  labels = merge(local.secret_labels, { usage = "netbird-admin-password" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "netbird_admin_password" {
  secret      = google_secret_manager_secret.netbird_admin_password.id
  secret_data = var.netbird_admin_password

  depends_on = [google_secret_manager_secret.netbird_admin_password]
}