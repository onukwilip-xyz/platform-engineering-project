resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_chart_version
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      defaultRevision = "default"
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  version          = var.istio_chart_version
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      env = {
        ENABLE_NATIVE_SIDECARS = "true"
      }

      meshConfig = {
        enablePrometheusMerge = true

        enableTracing = true

        defaultConfig = {
          holdApplicationUntilProxyStarts = true

          tracing = {
            sampling = 1
            openTelemetry = {
              address = var.otel_collector_address
            }
          }
        }
      }
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [helm_release.istio_base]
}