# ── Injected by Terragrunt inputs = {} ───────────────────────────────────────

variable "tf_platform_sa_email" {
  type        = string
  description = "Platform SA email. Injected from env.hcl via Terragrunt inputs."
}

variable "tf_network_sa_email" {
  type        = string
  description = "Network SA email. Injected from env.hcl via Terragrunt inputs."
}

variable "service_project_id" {
  type        = string
  description = "Service project ID. Injected from the gke dependency output."
}

variable "dns_project_id" {
  type        = string
  description = "Host project ID where Cloud DNS zones live. Injected from the gke dependency output."
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

# ── Static config (can also go in secrets.tfvars) ────────────────────────────

variable "namespace" {
  type    = string
  default = "cert-manager"
}

variable "cert_manager_chart_version" {
  type    = string
  default = "v1.17.1"
}

variable "cert_manager_google_service_account_id" {
  type        = string
  description = "Account ID for the GCP service account cert-manager uses for DNS-01 challenges."
  default     = "cert-manager-dns"
}

variable "cert_manager_k8s_service_account_name" {
  type    = string
  default = "cert-manager"
}

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
  default = "letsencrypt-public"
}

variable "acme_server" {
  type    = string
  default = "https://acme-v02.api.letsencrypt.org/directory"
}