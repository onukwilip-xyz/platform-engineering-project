terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.19.0"
      configuration_aliases = [google.platform, google.net]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}