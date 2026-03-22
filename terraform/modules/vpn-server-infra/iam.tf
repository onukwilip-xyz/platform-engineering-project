resource "google_service_account" "netbird_server" {
  provider     = google.platform
  account_id   = var.netbird_server_service_account_id
  display_name = var.netbird_server_service_account_name
  description  = var.netbird_server_service_account_description
  project      = var.service_project_id
}

resource "google_secret_manager_secret_iam_member" "server_pat_version_adder" {
  provider  = google.net
  project   = var.service_project_id
  secret_id = google_secret_manager_secret.netbird_pat.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = google_service_account.netbird_server.member

  depends_on = [ google_secret_manager_secret.netbird_pat ]
}

resource "google_project_iam_member" "server_log_writer" {
  provider = google.net
  project  = var.service_project_id
  role     = "roles/logging.logWriter"
  member   = google_service_account.netbird_server.member
}