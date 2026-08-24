resource "google_dns_record_set" "ddos_plane" {
  provider     = google.net
  project      = local.shared_vpc_host_project_id
  managed_zone = local.private_dns_zone_name
  name         = "${var.ddos_plane_dns_subdomain}.${local.env_record_prefix}${local.private_dns_zone_dns_name}"
  type         = "A"
  ttl          = var.ddos_plane_dns_ttl
  rrdatas      = [google_compute_address.master_nic1.address]
}