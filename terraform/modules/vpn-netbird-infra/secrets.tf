resource "google_secret_manager_secret" "netbird_routing_peer_setup_key" {
  secret_id = var.netbird_routing_peer_setup_key_secret_id
  project   = var.service_project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "netbird_routing_peer_setup_key" {
  secret      = google_secret_manager_secret.netbird_routing_peer_setup_key.id
  secret_data = netbird_setup_key.routing_peer.key

  depends_on = [ netbird_setup_key.routing_peer ]
}