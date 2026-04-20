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
      profile = "ambient" # For Ambient mode

      env = {
        # ENABLE_NATIVE_SIDECARS = "true" // Not needed in Ambient mode
      }

      meshConfig = {
        # enablePrometheusMerge = true // Not needed in Ambient mode

        enableTracing = true

        defaultConfig = {
          # holdApplicationUntilProxyStarts = true // Not needed in Ambient mode

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

resource "helm_release" "istio_cni" {
  name             = "istio-cni"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "cni"
  version          = var.istio_chart_version
  namespace        = "kube-system"  # CNI must live in kube-system on GKE
  create_namespace = false

  values = [
    yamlencode({
      profile = "ambient"

      cni = {
        cniBinDir  = "/home/kubernetes/bin"
        chained    = true
      }

      ambient = {
        enabled = true
      }
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "ztunnel" {
  name             = "ztunnel"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "ztunnel"
  version          = var.istio_chart_version
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [helm_release.istiod, helm_release.istio_cni]
}