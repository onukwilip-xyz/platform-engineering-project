resource "cloudflare_ruleset" "rate_limiting" {
  zone_id     = var.cloudflare_zone_id
  name        = "DDoS Rate Limiting Rules"
  description = "Rate limiting for DDoS simulation"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      action      = "block"
      expression  = "(ends_with(http.host, \".${var.cloudflare_public_domain}\")) or (http.host eq \"${var.cloudflare_public_domain}\")"
      description = "Throttle at 300/min"

      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = 50
        mitigation_timeout  = 10
      }
    }
  ]
}
