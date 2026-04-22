# ── Project ───────────────────────────────────────────────────────────────────

variable "service_project_id" {
  type        = string
  description = "GCP project ID where the ESO service account lives and where consumer modules create Secret Manager secrets."
}

# ── ESO GCP service account ──────────────────────────────────────────────────

variable "eso_gcp_sa_id" {
  type        = string
  description = "Account ID of the shared GCP service account that per-namespace KSAs impersonate via WIF for Secret Manager access. Secret-level `secretAccessor` grants and KSA→GSA WIF bindings are declared in the consumer modules."
  default     = "external-secrets"
}