variable "host_project" {
  type        = string
  description = "The ID of the host project where Shared VPC will be created."
}

variable "service_project" {
  type        = string
  description = "The ID of the service project where Compute resources will be created."
}

variable "tf_network_sa_email" {
  type        = string
  description = "Service account email to impersonate for the tf-network provider."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Service account email to impersonate for the tf-platform provider."
}

variable "region" {
  type        = string
  description = "Default region for Google provider operations."
}

variable "gke_subnet" {
  type        = string
  description = "Default subnet for GKE cluster."
}