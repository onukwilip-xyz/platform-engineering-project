locals {
  public_backend_services = {
    for s in var.public_gateway_backend_services :
    "${s.namespace}/${s.name}" => s
  }
}

resource "kubernetes_manifest" "gcp_backend_policy" {
  for_each = local.public_backend_services

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "${each.value.name}-backend-policy"
      namespace = each.value.namespace
    }
    spec = {
      default = merge(
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
      targetRef = {
        group = ""
        kind  = "Service"
        name  = each.value.name
      }
    }
  }

  depends_on = [kubernetes_manifest.gateway_public]
}