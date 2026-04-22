include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}//terraform/envs/staging/microservice-chart"

  extra_arguments "secrets" {
    commands = get_terraform_commands_that_need_vars()
    optional_var_files = [
      find_in_parent_folders(".tfvars")
    ]
  }
}

dependency "project" {
  config_path = "../project"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs = {
    service_project_id = "mock-service-project-id"
  }
}

dependency "artifact_registry" {
  config_path = "../artifact-registry"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs = {
    repositories = {
      helm = {
        repository_id = "helm"
      }
    }
  }
}

inputs = {
  service_project_id   = dependency.project.outputs.service_project_id
  region               = local.env.region
  helm_repository_id   = dependency.artifact_registry.outputs.repositories.helm.repository_id
  chart_path           = "${get_repo_root()}/helm/custom-charts/microservice"
  impersonate_sa_email = local.env.tf_platform_sa_email
}