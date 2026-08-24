terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
    }
  }
}