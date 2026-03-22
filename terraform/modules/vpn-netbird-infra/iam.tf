resource "google_service_account" "netbird_routing_peer" {
  provider     = google.platform
  account_id   = var.netbird_routing_peer_service_account_id
  display_name = var.netbird_routing_peer_service_account_name
  description  = var.netbird_routing_peer_service_account_description
  project      = var.service_project_id
}

resource "google_secret_manager_secret_iam_member" "peer_setup_key_accessor" {
  provider  = google.net
  project   = var.service_project_id
  secret_id = google_secret_manager_secret.netbird_routing_peer_setup_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.netbird_routing_peer.member

  depends_on = [google_secret_manager_secret.netbird_routing_peer_setup_key]
}

resource "google_project_iam_member" "peer_log_writer" {
  provider = google.net
  project  = var.service_project_id
  role     = "roles/logging.logWriter"
  member   = google_service_account.netbird_routing_peer.member
}