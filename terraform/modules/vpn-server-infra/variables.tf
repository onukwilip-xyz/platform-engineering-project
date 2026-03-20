variable "host_project_id" {
  type        = string
  description = "Host project ID (Shared VPC host project that owns the VPC/subnets)."
}

variable "service_project_id" {
  description = "The service project ID, where the Netbird instances and related resources will be created"
  type        = string
}

variable "netbird_server_instance_name" {
  description = "Name of the Netbird server instance"
  type        = string
}

variable "zone" {
  description = "Google Cloud zone for the instances"
  type        = string
}

variable "region" {
  description = "Google Cloud region for static IP addresses"
  type        = string
}

variable "network" {
  description = "VPC network name"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork name"
  type        = string
}

variable "netbird_domain" {
  description = "Domain name for Netbird"
  type        = string
}

variable "dns_managed_zone_name" {
  description = "Name of the existing Google Cloud DNS managed zone to use for the Netbird domain"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
}

variable "netbird_pat_secret_id" {
  description = "The ID for the Secret Manager secret that will store the Netbird Personal Access Token (PAT)"
  type        = string
}