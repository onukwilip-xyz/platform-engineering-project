resource "google_compute_instance" "netbird_routing_peer" {
  name    = var.netbird_routing_peer_instance_name
  project = var.service_project_id
  zone    = var.zone

  machine_type   = "e2-small"
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
  }

  tags = ["ssh"]

  labels = {
    "type" : "netbird-routing-peer"
  }

  metadata = {
    startup-script = templatefile("${path.module}/scripts/netbird-routing-peer-startup.sh", {
      netbird_management_url = "https://${var.netbird_domain}",
      setup_key_secret_id    = google_secret_manager_secret.netbird_routing_peer_setup_key.id
    })
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  service_account {
    scopes = ["cloud-platform"]
    email  = google_service_account.netbird_routing_peer.email
  }

  depends_on = [
    null_resource.wait_for_pat,
    google_service_account.netbird_routing_peer
  ]
}
