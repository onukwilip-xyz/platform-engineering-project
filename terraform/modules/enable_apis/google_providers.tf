terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
      configuration_aliases = [google.net, google.platform]
    }
  }
}