
resource "kubernetes_namespace" "istio_ingress" {
  metadata {
    name = "istio-ingress"
  }
}

resource "kubernetes_namespace" "istio_ingress_internal" {
  metadata {
    name = "istio-ingress-internal"
  }
}
