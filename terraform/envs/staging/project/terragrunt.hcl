include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
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
  # Double-slash tells Terragrunt: copy the entire repo into cache and use
  # terraform/envs/staging/project as the working directory within it.
  # This preserves relative paths like ../../../modules so they resolve correctly.
  source = "${get_repo_root()}//terraform/envs/staging/project"

  extra_arguments "secrets" {
    commands = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  
  }
}

inputs = {
  tf_network_sa_email  = local.env.tf_network_sa_email
  tf_platform_sa_email = local.env.tf_platform_sa_email
  labels               = local.env.labels
}