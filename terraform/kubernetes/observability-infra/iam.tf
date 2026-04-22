resource "google_service_account" "loki_gcs" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.loki_gcp_sa_id
  display_name = "Loki GCS Backend SA"
  description  = "Impersonated via Workload Identity Federation by Loki pods to read and write log chunks, index, and rulers in GCS."
}

resource "google_storage_bucket_iam_member" "loki_object_user" {
  provider = google.platform

  bucket = google_storage_bucket.loki.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.loki_gcs.email}"
}

resource "google_service_account_iam_member" "loki_workload_identity" {
  provider = google.platform

  service_account_id = google_service_account.loki_gcs.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.service_project_id}.svc.id.goog[${var.logging_namespace}/${var.loki_ksa_name}]"
}

resource "google_service_account" "tempo_gcs" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.tempo_gcp_sa_id
  display_name = "Tempo GCS Backend SA"
  description  = "Impersonated via Workload Identity Federation by Tempo pods to read and write trace blocks in GCS."
}

resource "google_storage_bucket_iam_member" "tempo_object_user" {
  provider = google.platform

  bucket = google_storage_bucket.tempo.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.tempo_gcs.email}"
}

resource "google_service_account_iam_member" "tempo_workload_identity" {
  provider = google.platform

  service_account_id = google_service_account.tempo_gcs.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.service_project_id}.svc.id.goog[${var.tracing_namespace}/${var.tempo_ksa_name}]"
}
