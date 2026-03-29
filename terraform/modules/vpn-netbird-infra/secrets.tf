resource "google_secret_manager_secret" "netbird_routing_peer_setup_key" {
  provider = google.platform
  secret_id = var.netbird_routing_peer_setup_key_secret_id
  project   = var.service_project_id

  replication {
    auto {}
  }
}