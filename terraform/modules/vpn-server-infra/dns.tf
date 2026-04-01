resource "google_dns_record_set" "internal_app" {
  name         = "${var.netbird_domain}."
  managed_zone = var.dns_managed_zone_name
  type         = "A"
  ttl          = 300
  project      = var.project_id

  rrdatas = [google_compute_address.netbird_server.address]

  depends_on = [google_compute_address.netbird_server]
}