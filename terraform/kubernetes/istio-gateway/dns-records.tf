data "google_dns_managed_zone" "private_zone" {
  provider = google.net
  name     = var.private_dns_zone_name
  project  = var.host_project_id
}

resource "google_dns_record_set" "private_gateway_wildcard" {
  provider     = google.net
  name         = "*.${data.google_dns_managed_zone.private_zone.dns_name}"
  managed_zone = var.private_dns_zone_name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.private_gateway.address]
  project      = var.host_project_id
}

data "google_dns_managed_zone" "public_zone" {
  provider = google.net
  name     = var.public_dns_zone_name
  project  = var.host_project_id
}

resource "google_dns_record_set" "public_gateway_wildcard" {
  provider     = google.net
  name         = "*.${data.google_dns_managed_zone.public_zone.dns_name}"
  managed_zone = var.public_dns_zone_name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.public_gateway.address]
  project      = var.host_project_id
}