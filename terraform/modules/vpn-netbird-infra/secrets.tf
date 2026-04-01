resource "google_secret_manager_secret" "netbird_routing_peer_setup_key" {
  secret_id = var.netbird_routing_peer_setup_key_secret_id
  project   = var.project_id

  replication {
    auto {}
  }
}