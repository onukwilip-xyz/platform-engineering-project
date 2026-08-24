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

variable "subnets" {
  type = list(object({
    subnet_name = string
    subnet_cidr = string

    pods_secondary_range_name     = optional(string)
    pods_secondary_cidr           = optional(string)
    services_secondary_range_name = optional(string)
    services_secondary_cidr       = optional(string)
  }))
  description = "Subnets to create in the shared VPC. Secondary ranges are optional (omit both for non-GKE subnets)."

  validation {
    condition     = length(var.subnets) == length(toset([for s in var.subnets : s.subnet_name]))
    error_message = "subnets: each subnet_name must be unique."
  }
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