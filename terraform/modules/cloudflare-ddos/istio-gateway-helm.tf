resource "helm_release" "istio_ingress" {
  name             = local.gateway_name
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  namespace        = var.istio_namespace
  create_namespace = true

  values =[
    yamlencode({
      service = {
        type                     = "LoadBalancer"
        loadBalancerIP           = google_compute_address.cf_gateway_ip.address
        loadBalancerSourceRanges = data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs
      }
      labels = {
        "gateway.networking.k8s.io/gateway-name" = local.gateway_name
      }
    })
  ]
}