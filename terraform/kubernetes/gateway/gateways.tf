resource "kubernetes_manifest" "gateway_gke" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "gke"
      namespace = kubernetes_namespace.gke_ingress.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = var.public_cluster_issuer_name
      }
    }
    spec = {
      gatewayClassName = var.public_gateway_class_name
      addresses = [
        {
          type  = "NamedAddress"
          value = google_compute_global_address.public_gateway.name
        }
      ]
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

  depends_on = [
    google_compute_global_address.public_gateway,
    kubernetes_namespace.gke_ingress,
  ]
}

# resource "kubernetes_manifest" "gateway_params_public" {
#   manifest = {
#     apiVersion = "gateway.istio.io/v1alpha1"
#     kind       = "GatewayParameters"
#     metadata = {
#       name      = "public-gateway-params"
#       namespace = kubernetes_namespace.istio_ingress.metadata[0].name
#     }
#     spec = {
#       kube = {
#         podSpec = {
#           priorityClassName = "high-priority"
#         }
#       }
#     }
#   }

#   depends_on = [kubernetes_namespace.istio_ingress]
# }

resource "kubernetes_manifest" "gateway_public" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = kubernetes_namespace.istio_ingress.metadata[0].name
      annotations = {
        "networking.istio.io/service-type" = "ClusterIP"
      }
    }
    spec = {
      gatewayClassName = var.gateway_class_name
      infrastructure = {
        parametersRef = {
          group = ""
          kind  = "ConfigMap"
          name  = kubernetes_config_map.gateway_params_public.metadata[0].name
        }
      }
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.istio_ingress,
    kubernetes_config_map.gateway_params_public
  ]
}

# resource "kubernetes_manifest" "gateway_params_internal" {
#   manifest = {
#     apiVersion = "gateway.istio.io/v1alpha1"
#     kind       = "GatewayParameters"
#     metadata = {
#       name      = "internal-gateway-params"
#       namespace = kubernetes_namespace.istio_ingress_internal.metadata[0].name
#     }
#     spec = {
#       kube = {
#         podSpec = {
#           priorityClassName = "high-priority"
#         }
#       }
#     }
#   }

#   depends_on = [kubernetes_namespace.istio_ingress_internal]
# }

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
        parametersRef = {
          group = ""
          kind  = "ConfigMap"
          name  = kubernetes_config_map.gateway_params_internal.metadata[0].name
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

  depends_on = [
    google_compute_address.private_gateway,
    kubernetes_config_map.gateway_params_internal,
  ]
}