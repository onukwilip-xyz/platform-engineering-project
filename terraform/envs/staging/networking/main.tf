data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = var.shared_state_prefix
  }
}

module "service_networking" {
  source = "../../../modules/service_networking"
  providers = {
    google = google.net
  }

  host_project_id        = data.terraform_remote_state.shared.outputs.host_project_id
  service_project_id     = var.service_project_id
  service_project_number = var.service_project_number
  region                 = var.region
  subnet_name            = data.terraform_remote_state.shared.outputs.gke_subnet_name
  tf_platform_sa_email   = var.tf_platform_sa_email
}