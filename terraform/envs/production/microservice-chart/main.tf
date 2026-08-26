module "microservice_chart" {
  source = "../../../modules/helm"

  service_project_id   = var.service_project_id
  registry_location    = var.region
  repository_id        = var.helm_repository_id
  chart_path           = var.chart_path
  impersonate_sa_email = var.impersonate_sa_email
}