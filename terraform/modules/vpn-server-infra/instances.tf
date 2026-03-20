resource "google_compute_instance" "netbird_server" {
  provider = google.platform
  
  name         = var.netbird_server_instance_name
  project      = var.service_project_id
  zone         = var.zone
  
  machine_type = "e2-small"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
    access_config {
        nat_ip = google_compute_address.netbird_server.address
    }
  }

  labels = {
    "type": "netbird-server"
  }

  metadata = {
    startup-script = templatefile("${path.module}/scripts/netbird-server-startup.sh", {
      domain        = var.netbird_domain
      letsencrypt_email = var.letsencrypt_email
      pat_secret_id = google_secret_manager_secret.netbird_pat.id
    })
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [ google_secret_manager_secret.netbird_pat ]
}