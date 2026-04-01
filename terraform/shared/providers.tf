provider "google" {
  impersonate_service_account = var.tf_network_sa_email
  region                      = var.region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}