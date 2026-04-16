variable "istio_chart_version" {
  type        = string
  description = "Version of the istio/gateway Helm chart. Must match the istiod version installed by the istio module."
}

variable "gateway_class_name" {
  type        = string
  description = "Name of the GatewayClass to use for both gateways. Passed from the gateway-api module output."
  default     = "istio"
}

# ── ClusterIssuer names ───────────────────────────────────────────────────────

variable "public_cluster_issuer_name" {
  type        = string
  description = "Name of the ACME ClusterIssuer for the public gateway's TLS certificate. Passed from cert-manager-config outputs."
  default     = "letsencrypt-public"
}

variable "internal_cluster_issuer_name" {
  type        = string
  description = "Name of the CA-backed ClusterIssuer for the private gateway's TLS certificate. Passed from cert-manager-config outputs."
  default     = "internal-ca"
}

# ── Domains ───────────────────────────────────────────────────────────────────

variable "public_domain" {
  type        = string
  description = "Root domain for public-facing services (e.g. example.com). The Gateway listener uses *.public_domain as its hostname."
}

variable "private_domain" {
  type        = string
  description = "Root domain for internal/VPC-only services (e.g. internal.example.com). The Gateway listener uses *.private_domain as its hostname."
}

# ── Static IP / DNS ───────────────────────────────────────────────────────────

variable "host_project_id" {
  type        = string
  description = "Host project ID where the VPC, subnets, and Cloud DNS zones live. Used to create the static IPs and the private DNS A record."
}

variable "region" {
  type        = string
  description = "GCP region for the static IP addresses (must match the GKE cluster region)."
}

variable "subnetwork" {
  type        = string
  description = "Self-link of the GKE subnet. The internal static IP is allocated from this subnet."
}

variable "private_dns_zone_name" {
  type        = string
  description = "Name of the Cloud DNS private managed zone (e.g. internal-pe-onukwilip-xyz). Used to create the wildcard A record."
}