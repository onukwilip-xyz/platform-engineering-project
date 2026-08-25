resource "google_compute_firewall" "allow_netbird_server_access" {
  name    = "allow-netbird-server-access"
  project = var.project_id
  network = var.network

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]

  target_tags = [var.netbird_server_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["3478"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}