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
  # Default Helm timeout (5 min) is too short when cert-manager pods restart
  # after an upgrade (e.g. adding --enable-gateway-api). 10 min is safe.
  timeout = 600

  depends_on = [
    kubernetes_namespace.cert_manager,
    google_service_account_iam_member.cert_manager_workload_identity,
  ]
}
