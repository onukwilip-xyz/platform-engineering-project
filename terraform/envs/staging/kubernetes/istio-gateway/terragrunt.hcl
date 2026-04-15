include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  k8s = read_terragrunt_config(find_in_parent_folders("kubernetes.hcl")).locals
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "destroy", "state", "apply"]
  mock_outputs                            = local.k8s.gke_mock_outputs
}

dependency "istio" {
  config_path = "../istio"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "destroy", "state", "apply"]
  mock_outputs                            = local.k8s.istio_mock_outputs
}

dependency "cert_manager_config" {
  config_path = "../cert-manager-config"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "destroy", "state", "apply"]
  mock_outputs                            = local.k8s.cert_manager_config_mock_outputs
}

generate "providers" {
  path      = "providers_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      impersonate_service_account = "${local.env.tf_platform_sa_email}"
    }

    provider "google" {
      alias                       = "net"
      impersonate_service_account = "${local.env.tf_network_sa_email}"
      region                      = "${local.env.region}"
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
  source = "${get_repo_root()}//terraform/kubernetes/istio-gateway"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  istio_chart_version          = dependency.istio.outputs.istio_chart_version
  gateway_class_name           = dependency.istio.outputs.gateway_class_name
  public_cluster_issuer_name   = dependency.cert_manager_config.outputs.public_cluster_issuer_name
  internal_cluster_issuer_name = dependency.cert_manager_config.outputs.internal_cluster_issuer_name

  # Static IP / DNS — sourced from the GKE unit which re-exports shared-state values
  host_project_id       = dependency.gke.outputs.host_project_id
  region                = local.env.region
  subnetwork            = dependency.gke.outputs.gke_subnet_self_link
  private_dns_zone_name = dependency.gke.outputs.private_dns_zone_name
}