variable "netbird_server_instance_name" {
  description = "Name of the Netbird server instance"
  type        = string
}

variable "netbird_routing_peer_instance_name" {
  description = "Name of the Netbird routing peer instance"
  type        = string
}

variable "project_id" {
  description = "Google Cloud project ID"
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

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
}

variable "netbird_pat_secret_id" {
  description = "The ID for the Secret Manager secret that will store the Netbird Personal Access Token (PAT)"
  type        = string
}

variable "netbird_routing_peer_setup_key_secret_id" {
  description = "The ID for the Secret Manager secret that will store the Netbird routing peer setup key"
  type        = string
}