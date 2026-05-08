terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.19.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
