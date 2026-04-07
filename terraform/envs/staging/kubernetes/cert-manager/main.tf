module "cert_manager" {
  source = "../../../../kubernetes/cert-manager"

  providers = {
    google.platform = google.platform
    google.net      = google.net
    kubernetes      = kubernetes
    helm            = helm
  }

  tf_platform_sa_email = var.tf_platform_sa_email
  tf_network_sa_email  = var.tf_network_sa_email
  service_project_id   = var.service_project_id
  dns_project_id       = var.dns_project_id

  namespace                              = var.namespace
  cert_manager_chart_version             = var.cert_manager_chart_version
  cert_manager_google_service_account_id = var.cert_manager_google_service_account_id
  cert_manager_k8s_service_account_name  = var.cert_manager_k8s_service_account_name
}