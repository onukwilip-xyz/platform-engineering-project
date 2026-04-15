include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  k8s = read_terragrunt_config(find_in_parent_folders("kubernetes.hcl")).locals
}

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
      impersonate_service_account = "${local.env.tf_platform_sa_email}"
    }

    data "google_client_config" "default" {}

    provider "kubernetes" {
      host                   = "https://${dependency.gke.outputs.gke_cluster_endpoint}"
      token                  = data.google_client_config.default.access_token
      cluster_ca_certificate = base64decode("${dependency.gke.outputs.gke_cluster_ca_certificate}")
    }

    provider "helm" {
      kubernetes = {
        host                   = "https://${dependency.gke.outputs.gke_cluster_endpoint}"
        token                  = data.google_client_config.default.access_token
        cluster_ca_certificate = base64decode("${dependency.gke.outputs.gke_cluster_ca_certificate}")
      }
    }
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/kubernetes/istio"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {}