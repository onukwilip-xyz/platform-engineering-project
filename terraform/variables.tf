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

variable "zone" {
  type        = string
  description = "Default zone for Google provider operations."
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
  description = "Secondary CIDR range for Pods (VPC-native)."
}

variable "services_secondary_range_name" {
  type        = string
  description = "Secondary range name for Services."
}

variable "services_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for Services."
}

variable "gke_cluster_name" {
  type = string
  description = "The name of the GKE Cluster to be created"
}

variable "gke_master_ipv4_cidr_block" {
  type = string
  description = "The CIDR block for the GKE master IPv4 range (must not overlap with VPC/subnet/secondary ranges)."
}

variable "gke_node_service_account_id" {
  type = string
  description = "The ID of the service account to be used by GKE nodes (without the @... suffix)."
}

variable "gke_resource_labels" {
  type        = map(string)
  description = "Resource labels to apply to the GKE cluster."
  default     = {}
}