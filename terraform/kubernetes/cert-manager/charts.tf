resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      crds = {
        enabled = true
      },
      serviceAccount = {
        name = var.cert_manager_k8s_service_account_name
        annotations = {
          "iam.gke.io/gcp-service-account" = google_service_account.cert_manager_dns.email
        }
      },
      extraArgs = ["--enable-gateway-api"]
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_namespace.cert_manager,
    google_service_account_iam_member.cert_manager_workload_identity,
  ]
}

resource "helm_release" "trust_manager" {
  name             = "trust-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "trust-manager"
  version          = var.trust_manager_chart_version
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      app = {
        trust = {
          namespace = kubernetes_namespace.cert_manager.metadata[0].name
        }
      }
      secretTargets = {
        enabled           = true
        authorizedSecrets = ["internal-ca-bundle"]
      }
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [helm_release.cert_manager]
}
