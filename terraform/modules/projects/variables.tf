variable "org_id" {
  type        = string
  description = "Organization ID for the Google Cloud organization."
}

variable "project_name" {
  type        = string
  description = "The name and ID prefix for the GCP project to create."
}

variable "billing_account_id" {
  type        = string
  description = "The ID of the billing account associated with the project."
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the GCP project resource."
  default     = {}
}