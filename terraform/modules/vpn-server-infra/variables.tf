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

variable "netbird_server_service_account_id" {
  description = "Service account ID for the Netbird server"
  type        = string
}

variable "netbird_server_service_account_name" {
  description = "Display name for the Netbird server service account"
  type        = string
}

variable "netbird_server_service_account_description" {
  description = "Description for the Netbird server service account"
  type        = string
}

variable "ssh_network_tag" {
  description = "Network tag for SSH firewall rule"
  type        = string
}

variable "netbird_server_network_tag" {
  description = "Network tag for the Netbird server instance"
  type        = string
}

variable "netbird_admin_email" {
  description = "Email address for the initial Netbird admin user"
  type        = string
}

variable "netbird_admin_password" {
  description = "Password for the initial Netbird admin user"
  type        = string
  sensitive   = true
}

variable "netbird_service_user_name" {
  description = "Name for the Netbird service user"
  type        = string
}

variable "netbird_service_user_token_name" {
  description = "Name for the Netbird service user token"
  type        = string
}