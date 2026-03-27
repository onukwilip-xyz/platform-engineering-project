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

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token with DNS edit permissions"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Cloudflare Zone ID for your root domain"
}

variable "root_domain" {
  type        = string
  description = "Your root domain"
  default     = "onukwilip.xyz"
}

variable "subdomain" {
  type        = string
  description = "Subdomain to delegate to Google Cloud DNS from Cloudflare (e.g. 'pe' for pe.onukwilip.xyz)"
  default     = "pe"
}

variable "private_subdomain" {
  type        = string
  description = "Private subdomain for internal DNS records (e.g. 'internal' for internal.pe.onukwilip.xyz)"
  default     = "internal"
}

# VPN Configuration
variable "netbird_server_instance_name" {
  type        = string
  description = "Name of the Netbird server instance"
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

variable "netbird_domain" {
  type        = string
  description = "Domain name for Netbird"
}

variable "dns_managed_zone_name" {
  type        = string
  description = "Name of the existing Google Cloud DNS managed zone to use for the Netbird domain"
}

variable "letsencrypt_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate registration"
}

variable "netbird_pat_secret_id" {
  type        = string
  description = "The ID for the Secret Manager secret that will store the Netbird Personal Access Token (PAT)"
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

variable "netbird_admin_password_secret_id" {
  description = "The ID for the Secret Manager secret that will store the Netbird admin password"
  type        = string
  sensitive = true
}

variable "netbird_service_user_name" {
  description = "Name for the Netbird service user"
  type        = string
}

variable "netbird_service_user_token_name" {
  description = "Name for the Netbird service user token"
  type        = string
}

variable "netbird_routing_peer_instance_name" {
  type        = string
  description = "Name of the Netbird routing peer instance"
}

variable "netbird_routing_peer_setup_key_secret_id" {
  type        = string
  description = "The ID for the Secret Manager secret that will store the Netbird routing peer setup key"
}

variable "netbird_routing_peer_setup_key_name" {
  description = "The name of the Netbird setup key to create for the routing peer"
  type        = string
}

variable "netbird_routing_peer_group_name" {
  description = "The name of the Netbird group to which the routing peer will be added"
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

variable "ssh_network_tag" {
  description = "Network tag for SSH firewall rule"
  type        = string
}

variable "netbird_server_network_tag" {
  description = "Network tag for the Netbird server instance"
  type        = string
}