terraform {
  required_providers {
    google = {
      source                = "hashicorp/google"
      version               = "7.28.0"
      configuration_aliases = [google.platform]
    }
  }
}