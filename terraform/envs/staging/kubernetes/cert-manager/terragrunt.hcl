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
    gke_cluster_endpoint       = "mock-endpoint"
    gke_cluster_ca_certificate = "bW9jaw=="
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
      kubernetes {
        host                   = "https://${dependency.gke.outputs.gke_cluster_endpoint}"
        token                  = data.google_client_config.default.access_token
        cluster_ca_certificate = base64decode("${dependency.gke.outputs.gke_cluster_ca_certificate}")
      }
    }

    provider "tls" {}
  EOF
}

terraform {
  source = "${get_repo_root()}//terraform/envs/staging/kubernetes/cert-manager"

  extra_arguments "secrets" {
    commands           = get_terraform_commands_that_need_vars()
    optional_var_files = [find_in_parent_folders("secrets.tfvars")]
  }
}

# Only dynamic values derived from other units go here.
# Static/sensitive values (ca_organization, acme_email, etc.) go in secrets.tfvars.
inputs = {
  tf_platform_sa_email = local.env.tf_platform_sa_email
  tf_network_sa_email  = local.env.tf_network_sa_email
  service_project_id   = dependency.project.outputs.service_project_id
  dns_project_id       = dependency.gke.outputs.host_project_id
}