output "eso_gcp_sa_email" {
  description = "Email of the shared ESO GSA. Consumer modules reference it to grant per-secret `secretAccessor` and bind their KSAs via WIF."
  value       = google_service_account.external_secrets.email
}

output "eso_gcp_sa_name" {
  description = "Fully-qualified name of the shared ESO GSA (projects/.../serviceAccounts/...). Consumer modules pass this to `google_service_account_iam_member` when binding their KSAs."
  value       = google_service_account.external_secrets.name
}