locals {
  public_gateway_backend_policy_default = merge(
    {
      timeoutSec = var.public_gateway_backend_timeout_sec
      logging = {
        enabled    = true
        sampleRate = var.public_gateway_backend_log_sample_rate
      }
    },
    var.cloud_armor_security_policy_name == "" ? {} : {
      securityPolicy = var.cloud_armor_security_policy_name
    }
  )
}