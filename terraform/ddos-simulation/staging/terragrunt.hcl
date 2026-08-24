# ─────────────────────────────────────────────────────────────────────────────
# DDoS simulation — staging target
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # state_bucket = get_env("TF_STATE_BUCKET", "pe-tf-state-bucket")
  state_bucket = get_env("TF_STATE_BUCKET", "pe-tf-state-bucket-1")
  env    = "staging"
  region = "us-central1"
  zone   = "us-central1-a"

  # tf_network_sa_email  = "tf-network@pe-terraform-project.iam.gserviceaccount.com"
  # tf_platform_sa_email = "tf-platform@pe-terraform-project.iam.gserviceaccount.com"
  tf_network_sa_email  = get_env("TF_NETWORK_SA", "tf-network@pe-terraform-project-1.iam.gserviceaccount.com")
  tf_platform_sa_email = get_env("TF_PLATFORM_SA", "tf-platform@pe-terraform-project-1.iam.gserviceaccount.com")
  shared_state_prefix  = "shared"
  gateway_state_prefix = "${local.env}/kubernetes/gateway/terraform.tfstate"
}

# Inline state backend — independent prefix so destroys don't touch envs/ state.
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
    commands = get_terraform_commands_that_need_vars()
    # Look for .tfvars in the unit's own directory first (unit-local), then
    # fall back to a shared one up the tree. compact() drops the misses.
    # find_in_parent_folders excludes the current dir, so the local lookup
    # is necessary when the operator keeps .tfvars next to terragrunt.hcl.
    optional_var_files = ["${get_terragrunt_dir()}/.tfvars"]
  }
}

inputs = {
  tf_platform_sa_email = local.tf_platform_sa_email
  state_bucket         = local.state_bucket
  shared_state_prefix  = local.shared_state_prefix
  gateway_state_prefix = local.gateway_state_prefix
  gke_subnet_region = local.region
  attack_region     = local.region
  attack_zone       = local.zone
}