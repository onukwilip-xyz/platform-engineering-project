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

dependency "gke" {
  config_path = "../../gke"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.gke_mock_outputs
}

dependency "tcp_services" {
  config_path = "../tcp-services"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.tcp_services_mock_outputs
}

generate "providers" {
  path      = "providers_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      alias                       = "platform"
      impersonate_service_account = "${local.env.tf_platform_sa_email}"
    }

    provider "google" {
      alias                       = "net"
      impersonate_service_account = "${local.env.tf_network_sa_email}"
      region                      = "${local.env.region}"
    }
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/kubernetes/cnpg-infra"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  service_project_id    = dependency.project.outputs.service_project_id
  region                = local.env.region
  labels                = local.env.labels
  host_project_id       = dependency.gke.outputs.host_project_id
  private_dns_zone_name = dependency.gke.outputs.private_dns_zone_name
  shared_vip_address    = dependency.tcp_services.outputs.shared_vip_address
}