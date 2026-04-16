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
      # infrastructure.annotations are propagated by Istio's Gateway controller
      # to the auto-provisioned LoadBalancer Service ("public-istio"), so GKE
      # assigns our static external IP instead of a random one.
      infrastructure = {
        annotations = {
          "networking.gke.io/load-balancer-type"         = "External"
          "networking.gke.io/load-balancer-ip-addresses" = google_compute_address.public_gateway.name
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

  depends_on = [helm_release.gateway_public, google_compute_address.public_gateway]
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
      # infrastructure.annotations are propagated by Istio's Gateway controller
      # to the auto-provisioned LoadBalancer Service ("private-istio"), so GKE
      # assigns our static internal IP instead of a random one.
      infrastructure = {
        annotations = {
          "networking.gke.io/load-balancer-type"         = "Internal"
          "networking.gke.io/load-balancer-ip-addresses" = google_compute_address.private_gateway.name
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
        }
      ]
    }
  }

  depends_on = [helm_release.gateway_internal, google_compute_address.private_gateway]
}