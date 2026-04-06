# Two Google provider aliases mirror the Shared VPC split:
#   google.net      — host project (networking, DNS, IAM for Shared VPC)
#   google.platform — service project (GKE, service accounts, Artifact Registry)
provider "google" {
  alias                       = "net"
  impersonate_service_account = var.tf_network_sa_email
  region                      = var.region
}

provider "google" {
  alias                       = "platform"
  impersonate_service_account = var.tf_platform_sa_email
  region                      = var.region
}

# ── Kubernetes + Helm providers ───────────────────────────────────────────────
# Provider blocks cannot reference module outputs or resource attributes, only
# variables and data sources. cluster_endpoint and cluster_ca_certificate must
# therefore be supplied as input variables (from the prior GKE layer's outputs).
#
# In CI/CD, populate them before running terraform init/apply on this layer:
#   export TF_VAR_cluster_endpoint=$(
#     terraform -chdir=environments/staging output -raw gke_cluster_endpoint)
#   export TF_VAR_cluster_ca_certificate=$(
#     terraform -chdir=environments/staging output -raw gke_cluster_ca_certificate)
#
# The short-lived OAuth2 token for the impersonated SA is used instead of a
# static kubeconfig or service account key.
data "google_client_config" "default" {
  provider = google.platform
}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${var.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}

provider "tls" {}