terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      configuration_aliases = [
        google.net,
        google.platform
      ]
    }
  }
}
