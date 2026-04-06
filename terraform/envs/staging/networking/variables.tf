variable "service_project_id" {
  type        = string
  description = "Service project ID. Passed from the project unit via dependency output."
}

variable "service_project_number" {
  type        = string
  description = "Service project number. Used for Shared VPC network user IAM bindings."
}

variable "region" {
  type        = string
  description = "GCP region."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Platform service account email — granted networkUser on the subnet."
}

variable "state_bucket" {
  type        = string
  description = "GCS bucket holding all Terraform state files (used to read shared layer outputs)."
}

variable "shared_state_prefix" {
  type        = string
  description = "State prefix for the shared layer (e.g. 'shared')."
}