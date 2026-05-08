resource "google_compute_firewall" "attack_iap_ssh" {
  project = module.attacker_project.project.project_id
  network = google_compute_network.attack.name
  name    = "allow-iap-ssh"

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.ssh_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "attack_egress_internet" {
  project = module.attacker_project.project.project_id
  network = google_compute_network.attack.name
  name    = "allow-egress-internet"

  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow attacker VMs (matched by network tag on nic1) to reach the private
# gateway IP on 443. Scoped tightly to that single IP, not the whole subnet.
resource "google_compute_firewall" "host_vpc_attacker_to_private_gateway" {
  provider = google.net
  project  = local.shared_vpc_host_project_id
  network  = local.shared_vpc_self_link
  name     = "allow-ddos-sim-metrics"

  direction          = "INGRESS"
  source_tags        = [var.metrics_egress_network_tag]
  destination_ranges = ["${local.private_gateway_ip}/32"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  depends_on = [google_compute_shared_vpc_service_project.attacker]
}