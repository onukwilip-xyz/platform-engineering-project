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

resource "google_compute_firewall" "allow_internal_access_subnet" {
  count = var.internal_access_subnet_key != null ? 1 : 0

  name    = "allow-${var.internal_access_subnet_key}-internal-tcp"
  project = var.host_project_id
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [google_compute_subnetwork.subnet[var.internal_access_subnet_key].ip_cidr_range]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}