terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.26.0"
      configuration_aliases = [google.platform, google.net]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
  }
}