resource "google_compute_instance" "netbird_server" {
  provider = google.platform

  name    = var.netbird_server_instance_name
  project = var.service_project_id
  zone    = var.zone

  machine_type = "e2-small"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    network            = var.network
    subnetwork         = var.subnetwork
    subnetwork_project = var.host_project_id
    access_config {
      nat_ip = google_compute_address.netbird_server.address
    }
  }

  tags = [
    var.ssh_network_tag,
    var.netbird_server_network_tag
  ]

  labels = {
    "type" : "netbird-server"
  }

  metadata = {
    startup-script = templatefile("${path.module}/scripts/netbird-server-startup.sh", {
      domain            = var.netbird_domain
      letsencrypt_email = var.letsencrypt_email
      pat_secret_id     = google_secret_manager_secret.netbird_pat.id
    })
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  service_account {
    scopes = ["cloud-platform"]
    email  = google_service_account.netbird_server.email
  }

  depends_on = [
    google_secret_manager_secret.netbird_pat,
    google_service_account.netbird_server
  ]
}

resource "google_compute_firewall" "allow_netbird_server_access" {
  provider = google.net
  name    = "allow-netbird-server-access"
  project = var.host_project_id
  network = var.network

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["0.0.0.0/0"]

  target_tags = [var.netbird_server_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
