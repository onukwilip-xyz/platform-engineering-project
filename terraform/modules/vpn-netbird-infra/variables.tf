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

variable "netbird_pat_secret_id" {
  description = "The ID for the Secret Manager secret that will store the Netbird Personal Access Token (PAT) for the routing peer to authenticate with the Netbird management server"
  type        = string
}

variable "netbird_group_id_parameter_id" {
  description = "The ID for the Parameter Manager parameter that will store the Netbird group ID"
  type        = string
}

variable "netbird_routing_peer_service_account_id" {
  description = "Service account ID for the Netbird routing peer"
  type        = string
}

variable "netbird_routing_peer_service_account_name" {
  description = "Display name for the Netbird routing peer service account"
  type        = string
}

variable "netbird_routing_peer_service_account_description" {
  description = "Description for the Netbird routing peer service account"
  type        = string
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Service account email to impersonate for the tf-platform provider."
}

# Google Workspace Identity Provider configuration
variable "enable_google_idp" {
  description = "Whether to enable Google Workspace identity provider integration. Requires google_oauth_client_id and google_oauth_client_secret to be set. See README.md for pre-requisites."
  type        = bool
  default     = false
}

variable "google_oauth_client_id" {
  description = "Google OAuth 2.0 Client ID (from the pre-created OAuth client in GCP Console). Required when enable_google_idp = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth 2.0 Client Secret (from the pre-created OAuth client in GCP Console). Required when enable_google_idp = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "netbird_idp_name" {
  description = "Display name for the identity provider in Netbird (e.g., 'Google Workspace')"
  type        = string
  default     = "Google Workspace"
}

variable "netbird_idp_redirect_uri_parameter_id" {
  description = "Parameter Manager parameter ID for storing the Netbird identity provider redirect URI"
  type        = string
  default     = ""
}

# Netbird user invitations
variable "netbird_users" {
  description = "List of users to create in Netbird and send invitations to. Each user requires name, email, and role (admin, user, or owner)."
  type = list(object({
    name  = string
    email = string
    role  = string
  }))
  default = []

  validation {
    condition     = alltrue([for u in var.netbird_users : contains(["admin", "user", "owner"], u.role)])
    error_message = "Each user's role must be one of: admin, user, owner."
  }
}