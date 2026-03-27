resource "google_secret_manager_secret" "netbird_pat" {
  provider = google.platform
  
  secret_id = var.netbird_pat_secret_id
  project   = var.service_project_id

  labels = {
    usage = "netbird-pat"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "netbird_admin_password" {
  provider = google.platform
  
  secret_id = var.netbird_admin_password_secret_id
  project   = var.service_project_id

  labels = {
    usage = "netbird-admin-password"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "netbird_admin_password" {
  provider    = google.platform
  secret      = google_secret_manager_secret.netbird_admin_password.id
  secret_data = var.netbird_admin_password

  depends_on = [google_secret_manager_secret.netbird_admin_password]
}