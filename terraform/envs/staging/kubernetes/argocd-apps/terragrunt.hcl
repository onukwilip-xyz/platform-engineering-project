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

dependency "argocd" {
  config_path = "../argocd"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.argocd_mock_outputs
}

dependency "cnpg_infra" {
  config_path = "../cnpg-infra"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.cnpg_infra_mock_outputs
}

dependency "tcp_services" {
  config_path = "../tcp-services"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.tcp_services_mock_outputs
}

dependency "cert_manager_config" {
  config_path = "../cert-manager-config"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.cert_manager_config_mock_outputs
}

dependency "istio_gateway" {
  config_path = "../istio-gateway"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.istio_gateway_mock_outputs
}

dependency "observability_infra" {
  config_path = "../observability-infra"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy", "state"]
  mock_outputs                            = local.k8s.observability_infra_mock_outputs
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
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/kubernetes/argocd-apps"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  argocd_namespace          = dependency.argocd.outputs.namespace
  backup_gcp_sa_email       = dependency.cnpg_infra.outputs.backup_gcp_sa_email
  backup_bucket_name        = dependency.cnpg_infra.outputs.backup_bucket_name
  shared_vip_address        = dependency.tcp_services.outputs.shared_vip_address
  cluster_issuer_name       = dependency.cert_manager_config.outputs.internal_cluster_issuer_name
  private_gateway_name      = dependency.istio_gateway.outputs.internal_gateway_name
  private_gateway_namespace = dependency.istio_gateway.outputs.internal_gateway_namespace
  loki_gcs_bucket_name      = dependency.observability_infra.outputs.loki_bucket_name
  loki_gcs_sa_email         = dependency.observability_infra.outputs.loki_gcp_sa_email
  tempo_gcs_bucket_name     = dependency.observability_infra.outputs.tempo_bucket_name
  tempo_gcs_sa_email        = dependency.observability_infra.outputs.tempo_gcp_sa_email
}