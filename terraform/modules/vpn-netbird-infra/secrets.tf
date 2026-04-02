locals {
  secret_labels = merge(var.labels, {
    purpose     = "vpn-credentials"
    gcp-product = "secret-manager"
  })
}

resource "google_secret_manager_secret" "netbird_routing_peer_setup_key" {
  secret_id = var.netbird_routing_peer_setup_key_secret_id
  project   = var.project_id

  labels = merge(local.secret_labels, { usage = "netbird-routing-peer-setup-key" })

  replication {
    auto {}
  }
}