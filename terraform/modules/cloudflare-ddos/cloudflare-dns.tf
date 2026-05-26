resource "cloudflare_dns_record" "wildcard_proxy" {
  zone_id = var.cloudflare_zone_id
  name    = "*.${var.cloudflare_public_domain}"
  content   = google_compute_address.cf_gateway_ip.address
  type    = "A"
  proxied = true
  ttl = 1
}

resource "cloudflare_dns_record" "root_proxy" {
  zone_id = var.cloudflare_zone_id
  name    = var.cloudflare_public_domain
  content   = google_compute_address.cf_gateway_ip.address
  type    = "A"
  proxied = true
  ttl = 1
}