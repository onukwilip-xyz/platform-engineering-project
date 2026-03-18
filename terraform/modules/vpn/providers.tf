# providers.tf

terraform {
  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
    }
    google = {
      source  = "hashicorp/google"
    }
  }
}

# PAT is read from Secret Manager after Phase 1 completes
data "google_secret_manager_secret_version" "netbird_pat" {
  secret  = google_secret_manager_secret.netbird_pat.secret_id

  depends_on = [null_resource.wait_for_pat]
}

provider "netbird" {
  endpoint = "https://${var.netbird_domain}"
  token    = data.google_secret_manager_secret_version.netbird_pat.secret_data
}