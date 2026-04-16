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
        loadBalancerIP = google_compute_address.public_gateway.address
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
        # Internal annotation provisions an Internal Passthrough NLB (L4).
        loadBalancerIP = google_compute_address.private_gateway.address
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