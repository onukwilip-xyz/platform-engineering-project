locals {
  # Static keys (0-3), dynamic values — keys are known at plan time ✅
  subdomain_ns_pairs = {
    for idx in range(4) :
    "${var.subdomain}-ns${idx}" => google_dns_managed_zone.public_zone.name_servers[idx]
  }
}

resource "cloudflare_dns_record" "subdomain_ns_all" {
  for_each = local.subdomain_ns_pairs

  zone_id = var.cloudflare_zone_id
  name    = "${var.subdomain}.${var.root_domain}"
  type    = "NS"
  ttl     = 86400

  content = trimsuffix(each.value, ".")

  depends_on = [google_dns_managed_zone.public_zone]
}