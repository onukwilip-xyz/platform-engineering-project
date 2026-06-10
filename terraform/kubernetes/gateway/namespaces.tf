
resource "kubernetes_namespace" "gke_ingress" {
  metadata {
    name = "gke-ingress"
  }
}

resource "kubernetes_namespace" "istio_ingress" {
  metadata {
    name = "istio-ingress"
    labels = {
      "istio.io/dataplane-mode" = "none"
    }
  }
}

resource "kubernetes_namespace" "istio_ingress_internal" {
  metadata {
    name = "istio-ingress-internal"
  }
}
