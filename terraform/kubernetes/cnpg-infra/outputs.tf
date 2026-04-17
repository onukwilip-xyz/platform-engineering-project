output "backup_bucket_name" {
  description = "GCS bucket name for CNPG Barman backups. Referenced in the Cluster CR's barmanObjectStore.destinationPath."
  value       = google_storage_bucket.cnpg_backup.name
}

output "backup_gcp_sa_email" {
  description = "Email of the GCP SA impersonated by CNPG pods via WIF. Referenced in the Cluster CR's serviceAccountTemplate annotation."
  value       = google_service_account.cnpg_backup.email
}

output "postgres_dns_name" {
  description = "FQDN for the PostgreSQL service (e.g. postgres.internal.pe.onukwilip.xyz)."
  value       = trimsuffix(google_dns_record_set.postgres.name, ".")
}