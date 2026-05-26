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

# * TEMP ── Users microservice (TEMP public exposure for the DDoS simulation) ───────
# Comment out together with the public users HTTPRoute once the simulation
# is concluded.
resource "kubernetes_manifest" "users_microservice_backend_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "users-microservice-backend-policy"
      namespace = kubernetes_namespace.users.metadata[0].name
    }
    spec = {
      default = local.public_gateway_backend_policy_default
      targetRef = {
        group = ""
        kind  = "Service"
        name  = "users-microservice-service"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.users_microservice,
    kubernetes_manifest.users_microservice_public_httproute,
  ]
}
