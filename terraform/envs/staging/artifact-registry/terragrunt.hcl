include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/envs/staging/artifact-registry"

  extra_arguments "secrets" {
    commands = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  
  }
}

dependency "project" {
  config_path = "../project"

  mock_outputs_allowed_terraform_commands = [
    "validate", "plan"
  ]

  mock_outputs = {
    service_project_id = "mock-service-project-id"
  }
}

inputs = {
  service_project_id = dependency.project.outputs.service_project_id
  region             = local.env.region
  labels             = local.env.labels
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

generate "providers" {
  path      = "providers_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
  provider "google" {
    alias                       = "platform"
    impersonate_service_account = "${local.env.tf_platform_sa_email}"
    region                      = "${local.env.region}"
  }

  EOF
}
