terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
  }
}