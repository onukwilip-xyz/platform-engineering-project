resource "google_compute_firewall" "allow_master_to_istio_webhook" {
  provider = google.net

  project = var.host_project_id
  name    = "${var.cluster_name}-allow-istio-webhook"
  network = var.network_self_link

  direction     = "INGRESS"
  source_ranges = [var.master_ipv4_cidr_block]

  target_service_accounts = [google_service_account.node_sa.email]

  allow {
    protocol = "tcp"
    ports    = ["15017"]
  }

  depends_on = [ google_service_account.node_sa ]
}

resource "google_compute_firewall" "gke_alb_and_healthcheck_istio" {
  provider = google.net

  name    = "gke-allow-alb-and-healthcheck-istio"
  network = var.network_self_link
  project = var.host_project_id

  allow {
    protocol = "tcp"
    ports    = ["15021", "80"]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "209.85.152.0/22",
    "209.85.204.0/22"
  ]

  target_service_accounts = [google_service_account.node_sa.email]

  description = "Allow GCP health checker to probe Istio gateway readiness on port 15021"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# resource "google_compute_firewall" "allow_iap_to_jump" {
#   provider = google.net

#   project = var.host_project_id
#   name    = var.jump_vm_iap_firewall_name
#   network = var.network_self_link

#   direction     = "INGRESS"
#   source_ranges = var.jump_vm_iap_source_ranges
#   target_tags   = var.jump_vm_iap_target_tags

#   allow {
#     protocol = "tcp"
#     ports    = var.jump_vm_iap_tcp_ports
#   }

#   log_config {
#     metadata = "INCLUDE_ALL_METADATA"
#   }
# }