resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "allow-ssh-iap"
  project = var.host_project_id
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]

  target_tags = [var.ssh_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}