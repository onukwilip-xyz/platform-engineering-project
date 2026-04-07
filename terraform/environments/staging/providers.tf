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