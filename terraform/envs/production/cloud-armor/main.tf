module "public_gateway_armor" {
  source = "../../../modules/cloud-armor"

  project_id  = var.service_project_id
  policy_name = var.policy_name

  rate_limit_threshold_count = var.rate_limit_threshold_count
  ban_threshold_count        = var.ban_threshold_count
  rate_limit_interval_sec    = var.rate_limit_interval_sec
  ban_duration_sec           = var.ban_duration_sec
  log_level                  = var.log_level
  rate_limit_preview         = var.rate_limit_preview
  enable_adaptive_protection = var.enable_adaptive_protection
}