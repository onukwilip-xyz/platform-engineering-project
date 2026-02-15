variable "host_project_id" {
  type        = string
  description = "Host project ID (Shared VPC host)."
}

variable "service_project_id" {
  type        = string
  description = "Service project ID (where GKE/VMs live)."
}

variable "region" {
  type        = string
  description = "Region for subnet/router/NAT."
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC in the host project."
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet in the host project."
}

variable "subnet_cidr" {
  type        = string
  description = "Primary CIDR range for the subnet (e.g., 10.1.0.0/20)."
}

variable "pods_secondary_range_name" {
  type        = string
  description = "Secondary range name for Pods (VPC-native)."
}

variable "pods_secondary_cidr" {
  type        = string
  description = "Secondary CIDR for Pods (e.g., 10.2.0.0/19)."
}

variable "services_secondary_range_name" {
  type        = string
  description = "Secondary range name for Services."
}

variable "services_secondary_cidr" {
  type        = string
  description = "Secondary CIDR for Services (e.g., 10.3.0.0/19)."
}

variable "enable_nat" {
  type        = bool
  description = "Whether to create Cloud NAT for egress."
  default     = true
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

variable "service_project_number" {
  type        = string
  description = "Service project number (needed for IAM bindings)."
}