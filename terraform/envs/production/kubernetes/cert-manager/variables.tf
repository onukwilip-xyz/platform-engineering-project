# ── Injected by Terragrunt inputs = {} ───────────────────────────────────────

variable "tf_platform_sa_email" {
  type        = string
  description = "Platform SA email."
}

variable "tf_network_sa_email" {
  type        = string
  description = "Network SA email."
}

variable "service_project_id" {
  type        = string
  description = "Service project ID."
}

variable "dns_project_id" {
  type        = string
  description = "Host project ID where Cloud DNS zones live."
}

# ── Static config ─────────────────────────────────────────────────────────────

variable "namespace" {
  type    = string
  default = "cert-manager"
}

variable "cert_manager_chart_version" {
  type    = string
  default = "v1.17.1"
}

variable "cert_manager_google_service_account_id" {
  type    = string
  default = "cert-manager-dns"
}

variable "cert_manager_k8s_service_account_name" {
  type    = string
  default = "cert-manager"
}