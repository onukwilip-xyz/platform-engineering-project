output "loki_bucket_name" {
  description = "GCS bucket name Loki writes to. Referenced in the Loki Helm values `storage.bucketNames.*`."
  value       = google_storage_bucket.loki.name
}

output "loki_gcp_sa_email" {
  description = "Email of the GCP SA Loki pods impersonate via WIF. Set as the value of the `iam.gke.io/gcp-service-account` annotation on Loki's KSA."
  value       = google_service_account.loki_gcs.email
}

output "tempo_bucket_name" {
  description = "GCS bucket name Tempo writes trace blocks to. Referenced in the Tempo Helm values `storage.trace.gcs.bucket_name`."
  value       = google_storage_bucket.tempo.name
}

output "tempo_gcp_sa_email" {
  description = "Email of the GCP SA Tempo pods impersonate via WIF. Set as the value of the `iam.gke.io/gcp-service-account` annotation on Tempo's KSA."
  value       = google_service_account.tempo_gcs.email
}