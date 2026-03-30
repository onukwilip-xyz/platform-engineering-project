variable "host_project_id" {
  type        = string
  description = "Host project ID (Shared VPC host)."
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
  description = "Secondary CIDR for Pods (e.g., 10.2.0.0/16)."
}

variable "services_secondary_range_name" {
  type        = string
  description = "Secondary range name for Services."
}

variable "services_secondary_cidr" {
  type        = string
  description = "Secondary CIDR for Services (e.g., 10.3.0.0/20)."
}

variable "enable_nat" {
  type        = bool
  description = "Whether to create Cloud NAT for egress."
  default     = true
}

variable "ssh_network_tag" {
  type        = string
  description = "Network tag for SSH firewall rule."
}