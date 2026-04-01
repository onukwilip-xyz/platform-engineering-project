variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare Zone ID for your root domain (e.g. onukwilip.xyz)"
  type        = string
  sensitive = true
}

variable "root_domain" {
  description = "Your root domain"
  type        = string
  default     = "onukwilip.xyz"
}

variable "subdomain" {
  description = "Subdomain to delegate to Google Cloud DNS from Cloudflare (e.g. 'pe' for pe.onukwilip.xyz)"
  type        = string
  default     = "pe"
}

variable "private_subdomain" {
  description = "Private subdomain for internal DNS records, (e.g. 'internal' for internal.pe.onukwilip.xyz)"
  type        = string
  default     = "internal"
}

variable "private_dns_network" {
  description = "The VPC self-link for the private DNS network"
  type        = string
}

variable "host_project_id" {
  type        = string
  description = "The ID of the host project where DNS resources will be created."
}

variable "labels" {
  type        = map(string)
  description = "Common labels applied to all DNS resources (e.g., env, team, managed-by). The module merges these with purpose and gcp-product automatically."
  default     = {}
}