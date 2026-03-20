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