# Two providers are required because GKE in a Shared VPC operates on both projects:
#   - google.net (network SA): host-project IAM for GKE robot SA, subnet network user for node SA, firewall rules
#   - google.platform (platform SA): cluster, node pools, service accounts in the service project

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