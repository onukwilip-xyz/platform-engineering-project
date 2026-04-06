# ── Google provider ──────────────────────────────────────────────────────────

variable "tf_platform_sa_email" {
  type        = string
  description = "Service account email the google.platform provider impersonates (manages GKE, service accounts, Workload Identity in the service project)."
}

variable "tf_network_sa_email" {
  type        = string
  description = "Service account email the google.net provider impersonates (manages IAM on the host project, e.g. Cloud DNS admin for the ACME solver)."
}

variable "cert_manager_google_service_account_id" {
  description = "Account ID (not email) for the cert-manager Google service account."
  type        = string
}

variable "cert_manager_k8s_service_account_name" {
  description = "Name of the cert-manager Kubernetes service account."
  type        = string
  default     = "cert-manager"
}

# ── GKE cluster credentials ──────────────────────────────────────────────────
# Provider configurations cannot reference data sources or module outputs, so
# these must be supplied explicitly (e.g. from the staging layer's outputs in CI):
#   TF_VAR_cluster_endpoint=$(terraform -chdir=environments/staging output -raw gke_cluster_endpoint)
#   TF_VAR_cluster_ca_certificate=$(terraform -chdir=environments/staging output -raw gke_cluster_ca_certificate)

variable "cluster_endpoint" {
  type        = string
  description = "GKE cluster API endpoint (raw IP or hostname, without the https:// scheme)."
  sensitive   = true
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Base64-encoded cluster CA certificate from the GKE master_auth block."
  sensitive   = true
}

# ── Project IDs ───────────────────────────────────────────────────────────────

variable "service_project_id" {
  type        = string
  description = "GCP project ID where the GKE cluster lives (used to create the cert-manager DNS service account and build the Workload Identity member string)."
}

variable "dns_project_id" {
  type        = string
  description = "GCP project ID where the Cloud DNS zones live (the host project). The cert-manager DNS service account is granted dns.admin here."
}

# ── cert-manager Helm release ─────────────────────────────────────────────────

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to install cert-manager into."
  default     = "cert-manager"
}

variable "cert_manager_chart_version" {
  type        = string
  description = "Version of the cert-manager Helm chart to install."
  default     = "v1.17.1"
}

# ── Internal CA (self-managed, for cluster/VPC-internal apps) ─────────────────

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

# ── Public ACME issuer (Let's Encrypt + Cloud DNS DNS-01) ─────────────────────

variable "public_cluster_issuer_name" {
  type        = string
  description = "Name of the ACME ClusterIssuer for public internet-facing certificates."
  default     = "letsencrypt-public"
}

variable "acme_email" {
  type        = string
  description = "Email address registered with Let's Encrypt for the ACME account (used for expiry notifications)."
}

variable "acme_server" {
  type        = string
  description = "Let's Encrypt ACME directory URL. Use the staging URL during initial testing to avoid rate limits, then switch to production."
  default     = "https://acme-v02.api.letsencrypt.org/directory"

  validation {
    condition = contains([
      "https://acme-v02.api.letsencrypt.org/directory",
      "https://acme-staging-v02.api.letsencrypt.org/directory",
    ], var.acme_server)
    error_message = "acme_server must be either the Let's Encrypt production or staging directory URL."
  }
}