module "artifact_registry" {
  source = "../../../modules/artifact_registry"
  providers = {
    google = google.platform
  }

  service_project_id = var.service_project_id
  region             = var.region
  repositories       = var.repositories
  labels             = var.labels
}