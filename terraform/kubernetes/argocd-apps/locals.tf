locals {
  users_db_username = "users_app"
  users_db_name     = "users"

  artifact_registry_images_host = "${var.region}-docker.pkg.dev/${var.service_project_id}/${var.artifact_registry_images_repo_id}"
  users_microservice_image      = "${local.artifact_registry_images_host}/users:${var.users_microservice_image_tag}"
  store_ui_image                = "${local.artifact_registry_images_host}/store-ui:${var.store_ui_image_tag}"
  critical_namespaces           = "postgres|cnpg-system"

  # Maps each dashboard JSON filename to the Grafana folder it lands in.
  # Add new entries here when new JSON files are dropped into grafana-dashboards/.
  dashboard_folders = {
    "kube-events-exporter.json"       = "Kubernetes Events"
    "detailed-cpu-usage-metrics.json" = "Kubernetes"
    "cloud-native-pg.json"            = "Database"
    "sloth-slo-overview.json"         = "SLOs"
    "sloth-slo-detail.json"           = "SLOs"
  }
}
