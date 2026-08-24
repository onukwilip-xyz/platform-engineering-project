resource "google_compute_security_policy" "this" {
  name        = var.policy_name
  project     = var.project_id
  description = var.description
  type        = "CLOUD_ARMOR"

  # Allow GCP load balancer health probes unconditionally so the LB never
  # marks the backend unhealthy during an attack.
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
      }
    }
    description = "Allow GCP health check probes"
  }

  # Per-IP rate-based ban: throttle at rate_limit_threshold, ban at ban_threshold.
  rule {
    action   = "rate_based_ban"
    priority = 2000
    preview  = var.rate_limit_preview
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_threshold_count
        interval_sec = var.rate_limit_interval_sec
      }
      ban_threshold {
        count        = var.ban_threshold_count
        interval_sec = var.rate_limit_interval_sec
      }
      ban_duration_sec = var.ban_duration_sec
    }
    description = "Throttle at ${var.rate_limit_threshold_count}/${var.rate_limit_interval_sec}s per IP, ban at ${var.ban_threshold_count}/${var.rate_limit_interval_sec}s for ${var.ban_duration_sec}s"
  }

  # Default rule (priority 2147483647 is the only allowed default priority).
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }

  dynamic "adaptive_protection_config" {
    for_each = var.enable_adaptive_protection ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable          = true
        rule_visibility = "STANDARD"
      }
    }
  }

  advanced_options_config {
    log_level = var.log_level
  }
}