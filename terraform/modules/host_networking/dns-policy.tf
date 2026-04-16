resource "google_dns_policy" "inbound_forwarding" {
  name    = "${var.vpc_name}-inbound-dns"
  project = var.host_project_id
  enable_inbound_forwarding = true

  networks {
    network_url = google_compute_network.vpc.self_link
  }
}