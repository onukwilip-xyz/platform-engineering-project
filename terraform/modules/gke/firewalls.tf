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