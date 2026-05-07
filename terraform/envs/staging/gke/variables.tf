variable "service_project_id" {
  type        = string
  description = "Service project ID."
}

variable "service_project_number" {
  type        = string
  description = "Service project number."
}

variable "region" {
  type        = string
  description = "GCP region for the GKE cluster."
}

variable "zone" {
  type        = string
  description = "GCP zone for the GKE cluster."
}

variable "state_bucket" {
  type        = string
  description = "GCS bucket holding all Terraform state files."
}

variable "shared_state_prefix" {
  type        = string
  description = "State prefix for the shared layer."
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster."
}

variable "monitoring_components" {
  type        = list(string)
  description = "List of monitoring components to enable (commonly SYSTEM_COMPONENTS and WORKLOADS)."
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "/28 CIDR for the GKE control plane."
}

variable "node_service_account_id" {
  type        = string
  description = "Account ID for the GKE node service account."
}

variable "node_pools" {
  type = list(object({
    name               = string
    machine_type       = string
    initial_node_count = number
    min_node_count     = number
    max_node_count     = number

    labels          = optional(map(string), {})
    resource_labels = optional(map(string), {})
    tags            = optional(list(string), [])

    max_surge       = optional(number)
    max_unavailable = optional(number)

    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  description = "Node pool definitions."
}

variable "jump_service_account_id" {
  type    = string
  default = "jump-vm-sa"
}

variable "jump_vm_name" {
  type    = string
  default = "jump-vm"
}

variable "jump_vm_access_sa_impersonators" {
  type    = list(string)
  default = []
}

variable "labels" {
  type    = map(string)
  default = {}
}