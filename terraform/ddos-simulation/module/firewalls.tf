# ── Attack VPC firewalls (in the attacker project) ──────────────────────────

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

resource "google_compute_firewall" "workers_to_master" {
  project = module.attacker_project.project.project_id
  network = google_compute_network.attack.name
  name    = "allow-workers-to-master"

  direction     = "INGRESS"
  source_ranges = [google_compute_subnetwork.attack.ip_cidr_range]
  target_tags   = [var.master_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["5557", "5558", "5559"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ── Shared VPC firewall — Locust web UI access from NetBird (commented out) ──
# The NetBird routing peer already has implicit reachability to other VMs in
# the host VPC, so this rule shouldn't be necessary. If browsing the Locust
# UIs at ddos-plane.<private_domain>:{8089,8090,8091} fails after apply,
# uncomment this resource to allow traffic from the GKE subnet to reach the
# master's nic1 on the web UI ports.
#
resource "google_compute_firewall" "host_vpc_to_master_ui" {
  provider = google.net
  project  = local.shared_vpc_host_project_id
  network  = local.shared_vpc_self_link
  name     = "allow-ddos-plane-ui"

  direction          = "INGRESS"
  source_ranges      = [data.terraform_remote_state.shared.outputs.gke_subnet_cidr]
  destination_ranges = ["${google_compute_address.master_nic1.address}/32"]

  allow {
    protocol = "tcp"
    ports    = ["8089", "8090", "8091"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  depends_on = [google_compute_shared_vpc_service_project.attacker]
}