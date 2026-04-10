resource "kubernetes_manifest" "gateway_class_istio" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "istio"
    }
    spec = {
      controllerName = "istio.io/gateway-controller"
    }
  }
}