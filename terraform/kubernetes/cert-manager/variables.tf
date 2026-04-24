# ── Google provider ───────────────────────────────────────────────────────────

variable "tf_platform_sa_email" {
  type        = string
  description = "Service account email the google.platform provider impersonates."
}

variable "tf_network_sa_email" {
  type        = string
  description = "Service account email the google.net provider impersonates."
}

# ── Project IDs ───────────────────────────────────────────────────────────────

variable "service_project_id" {
  type        = string
  description = "GCP project ID where the GKE cluster lives."
}

variable "dns_project_id" {
  type        = string
  description = "GCP project ID where Cloud DNS zones live (host project). The cert-manager DNS SA is granted dns.admin here."
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

variable "cert_manager_google_service_account_id" {
  type        = string
  description = "Account ID for the GCP service account cert-manager uses for DNS-01 challenges."
  default     = "cert-manager-dns"
}

variable "cert_manager_k8s_service_account_name" {
  type        = string
  description = "Name of the Kubernetes service account created by the cert-manager Helm chart."
  default     = "cert-manager"
}

variable "trust_manager_chart_version" {
  type        = string
  description = "Version of the trust-manager Helm chart to install."
  default     = "0.22.1"
}