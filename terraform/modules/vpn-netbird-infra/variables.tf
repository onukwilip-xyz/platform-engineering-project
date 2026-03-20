variable "netbird_routing_peer_setup_key_secret_id" {
  description = "The ID for the Secret Manager secret that will store the Netbird routing peer setup key"
  type        = string
}

variable "netbird_routing_peer_group_name" {
  description = "The name of the Netbird group to which the routing peer will be added"
  type        = string
}

variable "vpc_subnet_cidr" {
  description = "The CIDR range of the VPC subnet that should be routed through the Netbird routing peer (e.g. '10.0.0.0/24')"
  type        = string
}

variable "netbird_routing_peer_setup_key_name" {
  description = "The name of the Netbird setup key to create for the routing peer"
  type        = string
}

variable "netbird_routing_peer_instance_name" {
  description = "Name of the Netbird routing peer instance"
  type        = string
}

variable "service_project_id" {
  description = "The service project ID, where the Netbird instances and related resources will be created"
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