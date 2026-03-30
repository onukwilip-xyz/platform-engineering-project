variable "host_project_id" {
  type        = string
  description = "Host project ID (Shared VPC host)."
}

variable "service_project_id" {
  type        = string
  description = "Service project ID to attach to the Shared VPC."
}

variable "service_project_number" {
  type        = string
  description = "Service project number (needed for GKE robot and Cloud Services SA bindings)."
}

variable "region" {
  type        = string
  description = "Region of the subnet."
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet to grant network user access on."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Terraform platform SA email (needs subnet Network User)."
}

variable "extra_subnet_network_users" {
  type        = list(string)
  description = "Extra members to grant roles/compute.networkUser on the subnet."
  default     = []
}
