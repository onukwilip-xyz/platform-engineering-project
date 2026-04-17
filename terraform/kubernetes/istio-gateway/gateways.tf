resource "kubernetes_manifest" "gateway_public" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = kubernetes_namespace.istio_ingress.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = var.public_cluster_issuer_name
      }
    }
    spec = {
      addresses = [
        {
          type  = "IPAddress"
          value = google_compute_address.public_gateway.address
        }
      ]
      infrastructure = {
        annotations = {
          "networking.gke.io/load-balancer-type" = "External"
        }
      }
      gatewayClassName = var.gateway_class_name
      listeners = [
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          hostname = "*.${var.public_domain}"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name  = "public-gateway-cert"
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

  depends_on = [google_compute_address.public_gateway]
}

resource "kubernetes_manifest" "gateway_internal" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "private"
      namespace = kubernetes_namespace.istio_ingress_internal.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = var.internal_cluster_issuer_name
      }
    }
    spec = {
      addresses = [
        {
          type  = "IPAddress"
          value = google_compute_address.private_gateway.address
        }
      ]
      infrastructure = {
        annotations = {
          "networking.gke.io/load-balancer-type" = "Internal"
        }
      }
      gatewayClassName = var.gateway_class_name
      listeners = [
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          hostname = "*.${var.private_domain}"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name  = "private-gateway-cert"
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
        },
        {
          name     = "postgres"
          port     = 5432
          protocol = "TCP"
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "postgres"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [google_compute_address.private_gateway]
}