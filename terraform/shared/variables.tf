# ──────────────────────────────────────────────
# Provider / Auth
# ──────────────────────────────────────────────
variable "tf_network_sa_email" {
  type        = string
  description = "Service account email to impersonate for the Google provider (manages host project resources)."
}

variable "region" {
  type        = string
  description = "Default region for Google provider operations."
}

variable "zone" {
  type        = string
  description = "Default zone for Google provider operations."
}

# ──────────────────────────────────────────────
# Host Project
# ──────────────────────────────────────────────
variable "org_id" {
  type        = string
  description = "Organization ID for the Google Cloud organization."
}

variable "host_project_name" {
  type        = string
  description = "Name and ID prefix for the host project."
}

variable "billing_account_id" {
  type        = string
  description = "The ID of the billing account associated with the projects."
}

# ──────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────
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
  description = "Primary CIDR range for the subnet (e.g., 10.10.0.0/20)."
}

variable "pods_secondary_range_name" {
  type        = string
  description = "Secondary range name for Pods (VPC-native)."
}

variable "pods_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for Pods."
}

variable "services_secondary_range_name" {
  type        = string
  description = "Secondary range name for Services."
}

variable "services_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for Services."
}

variable "ssh_network_tag" {
  type        = string
  description = "Network tag for SSH firewall rule."
}

# ──────────────────────────────────────────────
# DNS
# ──────────────────────────────────────────────
variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token with DNS edit permissions."
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Cloudflare Zone ID for your root domain."
  sensitive   = true
}

variable "root_domain" {
  type        = string
  description = "Your root domain."
  default     = "onukwilip.xyz"
}

variable "subdomain" {
  type        = string
  description = "Subdomain to delegate to Google Cloud DNS from Cloudflare (e.g. 'pe' for pe.onukwilip.xyz)."
  default     = "pe"
}

variable "private_subdomain" {
  type        = string
  description = "Private subdomain for internal DNS records (e.g. 'internal' for internal.pe.onukwilip.xyz)."
  default     = "internal"
}

# ──────────────────────────────────────────────
# VPN Server Infrastructure
# ──────────────────────────────────────────────
variable "netbird_server_instance_name" {
  type        = string
  description = "Name of the Netbird server instance."
}

variable "netbird_domain" {
  type        = string
  description = "Domain name for Netbird."
}

variable "dns_managed_zone_name" {
  type        = string
  description = "Name of the Google Cloud DNS managed zone for the Netbird domain."
}

variable "letsencrypt_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate registration."
}

variable "netbird_pat_secret_id" {
  type        = string
  description = "The ID for the Secret Manager secret that will store the Netbird PAT."
}

variable "netbird_server_service_account_id" {
  type        = string
  description = "Service account ID for the Netbird server."
}

variable "netbird_server_service_account_name" {
  type        = string
  description = "Display name for the Netbird server service account."
}

variable "netbird_server_service_account_description" {
  type        = string
  description = "Description for the Netbird server service account."
}

variable "netbird_server_network_tag" {
  type        = string
  description = "Network tag for the Netbird server instance."
}

variable "netbird_admin_email" {
  type        = string
  description = "Email address for the initial Netbird admin user."
}

variable "netbird_admin_password" {
  type        = string
  description = "Password for the initial Netbird admin user."
  sensitive   = true
}

variable "netbird_admin_password_secret_id" {
  type        = string
  description = "The ID for the Secret Manager secret that will store the Netbird admin password."
  sensitive   = true
}

variable "netbird_service_user_name" {
  type        = string
  description = "Name for the Netbird service user."
}

variable "netbird_service_user_token_name" {
  type        = string
  description = "Name for the Netbird service user token."
}

# ──────────────────────────────────────────────
# VPN Netbird Routing Peer
# ──────────────────────────────────────────────
variable "netbird_routing_peer_instance_name" {
  type        = string
  description = "Name of the Netbird routing peer instance."
}

variable "netbird_routing_peer_group_name" {
  type        = string
  description = "The name of the Netbird group for the routing peer."
}

variable "netbird_routing_peer_setup_key_name" {
  type        = string
  description = "The name of the Netbird setup key for the routing peer."
}

variable "netbird_routing_peer_setup_key_secret_id" {
  type        = string
  description = "The ID for the Secret Manager secret storing the routing peer setup key."
}

variable "netbird_routing_peer_service_account_id" {
  type        = string
  description = "Service account ID for the Netbird routing peer."
}

variable "netbird_routing_peer_service_account_name" {
  type        = string
  description = "Display name for the Netbird routing peer service account."
}

variable "netbird_routing_peer_service_account_description" {
  type        = string
  description = "Description for the Netbird routing peer service account."
}

variable "netbird_group_id_parameter_id" {
  type        = string
  description = "Parameter Manager parameter ID for storing the Netbird group ID."
}

variable "netbird_route_cidrs" {
  type = list(object({
    cidr        = string
    network_id  = string
    description = string
  }))
  description = "List of CIDR ranges to route through the Netbird routing peer."
}

# Google Workspace Identity Provider
variable "enable_google_idp" {
  type        = bool
  description = "Whether to enable Google Workspace identity provider integration in Netbird."
  default     = false
}

variable "google_oauth_client_id" {
  type        = string
  description = "Google OAuth 2.0 Client ID."
  default     = ""
  sensitive   = true
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Google OAuth 2.0 Client Secret."
  default     = ""
  sensitive   = true
}

variable "netbird_idp_name" {
  type        = string
  description = "Display name for the identity provider in Netbird."
  default     = "Google Workspace"
}

variable "netbird_idp_redirect_uri_parameter_id" {
  type        = string
  description = "Parameter Manager parameter ID for storing the Netbird IDP redirect URI."
  default     = ""
}

# Netbird user invitations
variable "netbird_users" {
  type = list(object({
    name  = string
    email = string
    role  = string
  }))
  description = "List of users to create in Netbird and send invitations to."
  default     = []
}