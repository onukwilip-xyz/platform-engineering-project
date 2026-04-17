resource "google_service_account" "cnpg_backup" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.backup_gcp_sa_id
  display_name = "CNPG Barman Backup SA"
  description  = "Impersonated via Workload Identity Federation by CNPG cluster pods to write PostgreSQL backups to GCS."
}

resource "google_storage_bucket_iam_member" "cnpg_backup_bucket_reader" {
  provider = google.platform

  bucket = google_storage_bucket.cnpg_backup.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.cnpg_backup.email}"
}

resource "google_storage_bucket_iam_member" "cnpg_backup_object_admin" {
  provider = google.platform

  bucket = google_storage_bucket.cnpg_backup.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cnpg_backup.email}"
}

resource "google_service_account_iam_member" "cnpg_backup_workload_identity" {
  provider = google.platform

  service_account_id = google_service_account.cnpg_backup.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.service_project_id}.svc.id.goog[${var.postgres_namespace}/${var.cnpg_cluster_name}]"
}