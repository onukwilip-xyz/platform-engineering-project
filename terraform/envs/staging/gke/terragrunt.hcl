include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "project" {
  config_path = "../project"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    service_project_id     = "mock-service-project-id"
    service_project_number = "000000000000"
  }
}

# networking must be applied before gke (Shared VPC attachment must exist first)
dependency "networking" {
  config_path = "../networking"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs                            = {}
}

generate "providers" {
  path      = "providers_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      alias                       = "net"
      impersonate_service_account = "${local.env.tf_network_sa_email}"
      region                      = "${local.env.region}"
    }
    provider "google" {
      alias                       = "platform"
      impersonate_service_account = "${local.env.tf_platform_sa_email}"
      region                      = "${local.env.region}"
    }
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/envs/staging/gke"

  extra_arguments "secrets" {
    commands = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  
  }
}

inputs = {
  service_project_id     = dependency.project.outputs.service_project_id
  service_project_number = dependency.project.outputs.service_project_number
  region                 = local.env.region
  zone                   = local.env.zone
  labels                 = local.env.labels
  state_bucket           = local.env.state_bucket
  shared_state_prefix    = local.env.shared_state_prefix
}