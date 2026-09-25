terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.4.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.25.0"
    }
  }
}