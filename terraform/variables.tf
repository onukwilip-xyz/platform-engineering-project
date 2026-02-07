variable "tf_network_sa" {
  type        = string
  description = "Alias/name used for the tf-network provider configuration."
}

variable "org_id" {
  type        = string
  description = "Organization ID for the Google Cloud organization."
}

variable "host_project" {
  type        = string
  description = "The ID of the host project where Shared VPC will be created."
}

variable "service_project" {
  type        = string
  description = "The ID of the service project where Compute resources will be created."
}

variable "billing_account_id" {
  type        = string
  description = "The ID of the billing account associated with the projects."
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

variable "tf_state_bucket" {
  type        = string
  description = "GCS bucket name used for the Terraform remote state backend."
}

variable "gke_subnet" {
  type        = string
  description = "Default subnet for GKE cluster."
}