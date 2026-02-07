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