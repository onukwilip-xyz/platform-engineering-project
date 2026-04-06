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
      }
    })
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [
    kubernetes_namespace.cert_manager,
    google_service_account_iam_member.cert_manager_workload_identity,
  ]
}
