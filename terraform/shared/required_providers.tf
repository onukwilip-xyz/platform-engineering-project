terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.19.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.18.0"
    }
  }
}