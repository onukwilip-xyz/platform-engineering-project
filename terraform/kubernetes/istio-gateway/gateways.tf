resource "helm_release" "gateway_public" {
  name             = "istio-ingress-public"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  version          = var.istio_chart_version
  namespace        = kubernetes_namespace.istio_ingress.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      # Pod label used by the Gateway CR's selector to identify these proxy pods.
      labels = {
        istio = "ingress-public"
      }
      service = {
        # Default LoadBalancer on GKE provisions an External Passthrough NLB (L4).
        annotations = {
          "networking.gke.io/load-balancer-type" = "External"
        }
      }
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [kubernetes_namespace.istio_ingress]
}

resource "helm_release" "gateway_internal" {
  name             = "istio-ingress-internal"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  version          = var.istio_chart_version
  namespace        = kubernetes_namespace.istio_ingress_internal.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      labels = {
        istio = "ingress-internal"
      }
      service = {
        # Internal annotation provisions an Internal Passthrough NLB (L4),
        annotations = {
          "networking.gke.io/load-balancer-type" = "Internal"
        }
      }
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [kubernetes_namespace.istio_ingress_internal]
}

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

  depends_on = [helm_release.gateway_public]
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

  depends_on = [helm_release.gateway_internal]
}