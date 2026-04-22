locals {
  users_db_username = "users_app"
  users_db_name     = "users"

  artifact_registry_images_host = "${var.region}-docker.pkg.dev/${var.service_project_id}/${var.artifact_registry_images_repo_id}"
  users_microservice_image      = "${local.artifact_registry_images_host}/users:${var.users_microservice_image_tag}"
  store_ui_image                = "${local.artifact_registry_images_host}/store-ui:${var.store_ui_image_tag}"
}