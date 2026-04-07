include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

# cert-manager must be fully applied first so the ClusterIssuer CRD is
# registered in the cluster before this unit is planned.
dependency "cert_manager" {
  config_path = "../cert-manager"

  mock_outputs_allowed_terraform_commands = ["init", "validate"]
  mock_outputs = {
    namespace = "cert-manager"
  }
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs_allowed_terraform_commands = ["init", "validate"]
  mock_outputs = {
    gke_cluster_endpoint       = "127.0.0.1"
    gke_cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMFo1dnZaVThKVDNPUEZLL1NGRlYKTWREeGhsT3Y5WUNXcWpuQ3pTYk1PL05DNEpyVWU4SnlCeVlsRGNSaENsM0NmaGFSeGJaU0FwZElTeWREbgppWENscGJFaDVGL0pXVGhiTkZ0RXpJUVpYa3N4UVZvb3NOb0d6TUJVU3NXOE95UHVicmpjaFpuSTlIa1RHCkFQZlpERGhtZ3p4cmVDTUpvcFZ5aEdNVEE2blVMTFlOVk5ONjR4REVjUzZLc0xOdUhLMkpvbXh0UUlTRHkKdHZucUk1N0hhcGMyVHMxQTNnUHo0aXFhaFpFVFJsMFZYVktuYXFMRjFXZjk5OUVlNlpDVFY5YVdkaGhRTgpXZDlxV0QzWG5OZkdlQUlEN2pSUlRUcVBJQ2lScEZJbHdaTnJpMUkyYXZ3T29WTmNGcVJUWlVrSTQyVk1PClZ3SURBUUFCZ29BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBCkFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUEKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
    host_project_id            = "mock-host-project-id"
  }
}

# No "plan" in mock_outputs_allowed_terraform_commands — cert-manager-config
# must always be planned against a live cluster where the CRD exists.
# Use: terragrunt run-all plan --exclude-dir kubernetes on a fresh environment.

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

    provider "tls" {}
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/envs/staging/kubernetes/cert-manager-config"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  cert_manager_namespace = dependency.cert_manager.outputs.namespace
  dns_project_id         = dependency.gke.outputs.host_project_id
}