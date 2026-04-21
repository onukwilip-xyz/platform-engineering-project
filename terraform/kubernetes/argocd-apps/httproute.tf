resource "kubernetes_manifest" "grafana_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "grafana"
      namespace = kubernetes_namespace.grafana.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name        = var.private_gateway_name
          namespace   = var.private_gateway_namespace
          sectionName = "https"
        }
      ]
      hostnames = ["grafana.${var.private_domain}"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              # kube-prometheus-stack's grafana subchart collapses its fullname
              # to just the release name when the release name matches the chart
              # name. The ArgoCD Application is named "grafana", so the Service
              # ends up as `grafana` (not `grafana-grafana`).
              name = "grafana"
              port = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.grafana]
}