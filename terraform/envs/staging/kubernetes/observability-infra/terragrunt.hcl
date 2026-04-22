include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  k8s = read_terragrunt_config(find_in_parent_folders("kubernetes.hcl")).locals
}

dependency "project" {
  config_path = "../../project"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.project_mock_outputs
}

# Ordering-only dependency. The Workload Identity pool
# `<project>.svc.id.goog` referenced by the WI IAM bindings in iam.tf is
# created by the GKE cluster when `workload_identity_config` is enabled.
# Applying this unit before the cluster exists fails with "Identity Pool does
# not exist".
dependency "gke" {
  config_path = "../../gke"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.gke_mock_outputs
}

generate "providers" {
  path      = "providers_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      alias                       = "platform"
      impersonate_service_account = "${local.env.tf_platform_sa_email}"
    }
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/kubernetes/observability-infra"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  service_project_id = dependency.project.outputs.service_project_id
  region             = local.env.region
  labels             = local.env.labels
}