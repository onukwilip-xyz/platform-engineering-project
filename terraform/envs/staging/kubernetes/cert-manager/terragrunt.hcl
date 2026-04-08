include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "project" {
  config_path = "../../project"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    service_project_id     = "mock-service-project-id"
    service_project_number = "000000000000"
  }
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    gke_cluster_endpoint = "127.0.0.1"
    # A valid self-signed PEM cert, base64-encoded. Required because the
    # kubernetes provider validates the cert format at initialisation time,
    # even during plan with mock outputs. The actual value is replaced with
    # the real cluster CA cert on apply.
    gke_cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMFo1dnZaVThKVDNPUEZLL1NGRlYKTWREeGhsT3Y5WUNXcWpuQ3pTYk1PL05DNEpyVWU4SnlCeVlsRGNSaENsM0NmaGFSeGJaU0FwZElTeWREbgppWENscGJFaDVGL0pXVGhiTkZ0RXpJUVpYa3N4UVZvb3NOb0d6TUJVU3NXOE95UHVicmpjaFpuSTlIa1RHCkFQZlpERGhtZ3p4cmVDTUpvcFZ5aEdNVEE2blVMTFlOVk5ONjR4REVjUzZLc0xOdUhLMkpvbXh0UUlTRHkKdHZucUk1N0hhcGMyVHMxQTNnUHo0aXFhaFpFVFJsMFZYVktuYXFMRjFXZjk5OUVlNlpDVFY5YVdkaGhRTgpXZDlxV0QzWG5OZkdlQUlEN2pSUlRUcVBJQ2lScEZJbHdaTnJpMUkyYXZ3T29WTmNGcVJUWlVrSTQyVk1PClZ3SURBUUFCZ29BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBCkFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUEKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
    service_project_id         = "mock-service-project-id"
    host_project_id            = "mock-host-project-id"
  }
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
    }

    data "google_client_config" "default" {
      provider = google.platform
    }

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
  source = "${get_repo_root()}//terraform/envs/staging/kubernetes/cert-manager"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders(".tfvars")]
  }
}

inputs = {
  tf_platform_sa_email = local.env.tf_platform_sa_email
  tf_network_sa_email  = local.env.tf_network_sa_email
  service_project_id   = dependency.project.outputs.service_project_id
  dns_project_id       = dependency.gke.outputs.host_project_id
}