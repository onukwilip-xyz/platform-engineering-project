resource "kubernetes_config_map" "gateway_params_public" {
  metadata {
    name      = "public-gateway-params"
    namespace = kubernetes_namespace.istio_ingress.metadata[0].name
  }
  data = {
    deployment = yamlencode({
      spec = {
        template = {
          spec = {
            priorityClassName = "high-priority"
          }
        }
      }
    })
  }
  depends_on = [kubernetes_namespace.istio_ingress]
}

resource "kubernetes_config_map" "gateway_params_internal" {
  metadata {
    name      = "internal-gateway-params"
    namespace = kubernetes_namespace.istio_ingress_internal.metadata[0].name
  }

  data = {
    deployment = yamlencode({
      spec = {
        template = {
          spec = {
            priorityClassName = "high-priority"
          }
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.istio_ingress_internal]
}
