resource "google_service_account" "external_secrets" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.eso_gcp_sa_id
  display_name = "External Secrets Operator SA"
  description  = "Impersonated via Workload Identity Federation by per-namespace KSAs referenced in SecretStore CRs. Per-secret IAM bindings live in the consumer modules."
}