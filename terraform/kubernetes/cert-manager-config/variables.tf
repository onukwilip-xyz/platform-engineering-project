# ── Namespace (from cert-manager unit output) ─────────────────────────────────

variable "cert_manager_namespace" {
  type        = string
  description = "The cert-manager namespace name. Passed from the cert-manager unit's output so the CA secret is created in the correct namespace."
  default     = "cert-manager"
}

# ── Internal CA ───────────────────────────────────────────────────────────────

variable "ca_common_name" {
  type        = string
  description = "Common name (CN) embedded in the self-signed internal CA certificate."
  default     = "cluster-internal-ca"
}

variable "ca_organization" {
  type        = string
  description = "Organization name (O) embedded in the self-signed internal CA certificate."
}

variable "internal_cluster_issuer_name" {
  type        = string
  description = "Name of the CA-backed ClusterIssuer for internal cluster/VPC certificates."
  default     = "internal-ca"
}

# ── Public ACME issuer ────────────────────────────────────────────────────────

variable "public_cluster_issuer_name" {
  type        = string
  description = "Name of the ACME ClusterIssuer for public internet-facing certificates."
  default     = "letsencrypt-public"
}

variable "acme_email" {
  type        = string
  description = "Email address registered with Let's Encrypt for the ACME account."
}

variable "acme_server" {
  type        = string
  description = "Let's Encrypt ACME directory URL. Use the staging URL during initial testing to avoid rate limits."
  default     = "https://acme-v02.api.letsencrypt.org/directory"

  validation {
    condition = contains([
      "https://acme-v02.api.letsencrypt.org/directory",
      "https://acme-staging-v02.api.letsencrypt.org/directory",
    ], var.acme_server)
    error_message = "acme_server must be either the Let's Encrypt production or staging directory URL."
  }
}

variable "dns_project_id" {
  type        = string
  description = "GCP project ID where Cloud DNS zones live. Used by the public ACME ClusterIssuer DNS-01 solver."
}