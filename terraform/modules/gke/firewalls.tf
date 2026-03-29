resource "google_compute_firewall" "allow_iap_to_jump" {
  provider = google.net

  project = var.host_project_id
  name    = var.jump_vm_iap_firewall_name
  network = var.network_self_link

  direction     = "INGRESS"
  source_ranges = var.jump_vm_iap_source_ranges
  target_tags   = var.jump_vm_iap_target_tags

  allow {
    protocol = "tcp"
    ports    = var.jump_vm_iap_tcp_ports
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}