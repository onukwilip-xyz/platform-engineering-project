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

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# PAT is read from Secret Manager after Phase 1 completes
data "google_secret_manager_secret_version" "netbird_pat" {
  secret  = module.vpn_server_infra.netbird_pat_secret.id

  depends_on = [ module.vpn_server_infra ]
}

provider "netbird" {
  management_url = "https://${var.netbird_domain}"
  token    = data.google_secret_manager_secret_version.netbird_pat.secret_data
}