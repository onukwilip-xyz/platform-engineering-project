resource "kubernetes_manifest" "http_route" {
  for_each = var.exposed_services

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${each.key}-cf-route"
      namespace = each.value.namespace
    }
    spec = {
      parentRefs = [
        {
          name      = local.gateway_name
          namespace = var.istio_namespace
        }
      ]
      # hostnames = ["${each.key}.${var.cloudflare_public_domain}"]
      hostnames = [var.cloudflare_public_domain]
      rules = [
        {
          backendRefs = [
            {
              name = each.value.service_name
              port = each.value.port
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gateway_public_cf]
}
