terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.19.0"
      configuration_aliases = [google.net, google.platform]
    }
  }
}