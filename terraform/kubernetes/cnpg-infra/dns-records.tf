data "google_dns_managed_zone" "private_zone" {
  provider = google.net
  name     = var.private_dns_zone_name
  project  = var.host_project_id
}

resource "google_dns_record_set" "postgres" {
  provider     = google.net
  name         = "postgres.${data.google_dns_managed_zone.private_zone.dns_name}"
  managed_zone = var.private_dns_zone_name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.shared_vip_address]
  project      = var.host_project_id
}