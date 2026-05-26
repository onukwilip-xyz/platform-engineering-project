resource "kubernetes_manifest" "gateway_public_cf" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.gateway_name
      namespace = var.istio_namespace
      annotations = {
        "gateway.istio.io/managed" = "false"
      }
    }
    spec = {
      gatewayClassName = "istio"
      # addresses = [
      #   {
      #     type  = "IPAddress"
      #     value = google_compute_address.cf_gateway_ip.address
      #   }
      # ]
      addresses = [
        {
          type  = "Hostname"
          value = "${local.gateway_name}.${var.istio_namespace}.svc.cluster.local"
        }
      ]
      listeners = [
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          # hostname = "*.${var.cloudflare_public_domain}"
          hostname = var.cloudflare_public_domain
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name  = "cf-origin-tls"
                kind  = "Secret"
                group = ""
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.istio_ingress]
}
