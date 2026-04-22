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
        ENABLE_NATIVE_SIDECARS = "true"
      }

      meshConfig = {
        enablePrometheusMerge = true

        enableTracing = true

        defaultConfig = {
          holdApplicationUntilProxyStarts = true
        }

        # Registers Tempo under the name `tempo-otel`. Sidecars don't send
        # spans until a Telemetry CR activates this provider — configured
        # in the argocd-apps module alongside the Tempo Application.
        extensionProviders = [
          {
            name = "tempo-otel"
            opentelemetry = {
              service = "tempo.${var.tracing_namespace}.svc.cluster.local"
              port    = 4317
            }
          },
        ]
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

  timeout = 600
  depends_on = [
    helm_release.istiod,
    helm_release.istio_cni,
    kubernetes_resource_quota.istio_system_critical_pods,
  ]
}