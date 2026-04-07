# ── Injected by Terragrunt inputs = {} ───────────────────────────────────────

variable "cert_manager_namespace" {
  type        = string
  description = "cert-manager namespace. Injected from the cert-manager unit's output."
  default     = "cert-manager"
}

variable "dns_project_id" {
  type        = string
  description = "Host project ID where Cloud DNS zones live. Injected from the gke unit's output."
}

# ── Provided via secrets.tfvars ───────────────────────────────────────────────

variable "ca_organization" {
  type        = string
  description = "Organization name embedded in the internal CA certificate."
}

variable "acme_email" {
  type        = string
  description = "Email registered with Let's Encrypt for the ACME account."
}

# ── Static config ─────────────────────────────────────────────────────────────

variable "ca_common_name" {
  type    = string
  default = "cluster-internal-ca"
}

variable "internal_cluster_issuer_name" {
  type    = string
  default = "internal-ca"
}

variable "public_cluster_issuer_name" {
  type    = string
  default = "letsencrypt-public-ca"
}

variable "acme_server" {
  type    = string
  default = "https://acme-v02.api.letsencrypt.org/directory"
}