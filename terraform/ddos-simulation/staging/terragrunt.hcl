# ─────────────────────────────────────────────────────────────────────────────
# DDoS simulation — staging target
# ─────────────────────────────────────────────────────────────────────────────

locals {
  state_bucket = get_env("TF_STATE_BUCKET", "pe-tf-state-bucket")
  env    = "staging"
  region = "us-central1"

  tf_network_sa_email  = "tf-network@pe-terraform-project.iam.gserviceaccount.com"
  tf_platform_sa_email = "tf-platform@pe-terraform-project.iam.gserviceaccount.com"
  shared_state_prefix              = "shared"
  gateway_state_prefix             = "${local.env}/kubernetes/gateway/terraform.tfstate"
  cert_manager_config_state_prefix = "${local.env}/kubernetes/cert-manager-config/terraform.tfstate"
}

remote_state {
  backend = "gcs"
  config = {
    bucket = local.state_bucket
    prefix = "ddos-simulation/${local.env}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "providers" {
  path      = "providers_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      impersonate_service_account = "${local.tf_platform_sa_email}"
    }

    provider "google" {
      alias                       = "net"
      impersonate_service_account = "${local.tf_network_sa_email}"
      region                      = "${local.region}"
    }
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/ddos-simulation/module"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  tf_platform_sa_email = local.tf_platform_sa_email

  # Where to read live values from
  state_bucket                     = local.state_bucket
  shared_state_prefix              = local.shared_state_prefix
  gateway_state_prefix             = local.gateway_state_prefix
  cert_manager_config_state_prefix = local.cert_manager_config_state_prefix

  # Region of the GKE subnet (matches the staging env's region)
  gke_subnet_region = local.region

  # Attack/baseline regions (per agreed plan)
  attack_region   = "us-central1"
  baseline_region = "europe-west1"
  test_duration   = "30m"
}