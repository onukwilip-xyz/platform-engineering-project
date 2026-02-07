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