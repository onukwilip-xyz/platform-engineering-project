variable "service_project_id" {
  type        = string
  description = "GCP Service project ID for the static IP"
}

variable "region" {
  type        = string
  description = "GCP Region for the static IP"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Cloudflare Zone ID for the domain"
}

variable "cloudflare_public_domain" {
  type        = string
  description = "The public domain managed by Cloudflare (e.g. public.onukwilip.xyz)"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "istio_namespace" {
  type        = string
  description = "Namespace where Istio is installed"
  default     = "istio-ingress"
}

# Add map of services to expose
variable "exposed_services" {
  type = map(object({
    namespace    = string
    service_name = string
    port         = number
  }))
  description = "Map of microservices to expose through the Cloudflare HTTP routes"
}
