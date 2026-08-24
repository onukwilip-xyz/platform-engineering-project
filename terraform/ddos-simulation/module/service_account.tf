resource "google_service_account" "ddos_runner" {
  project      = module.attacker_project.project.project_id
  account_id   = "ddos-runner"
  display_name = "DDoS simulation runtime SA (master + workers)"
  description  = "Attached to the master VM and every worker MIG instance. Allowed to read locustfiles from GCS and write logs/metrics."

  depends_on = [
    module.attacker_apis,
    module.attacker_platform_iam,
  ]
}

module "ddos_runner_observability_iam" {
  source = "../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.attacker_project.project.project_id
  bindings = [
    { role = "roles/logging.logWriter", member = "serviceAccount:${google_service_account.ddos_runner.email}" },
    { role = "roles/monitoring.metricWriter", member = "serviceAccount:${google_service_account.ddos_runner.email}" },
  ]

  depends_on = [google_service_account.ddos_runner]
}

resource "google_storage_bucket_iam_member" "ddos_runner_locustfiles_read" {
  bucket = google_storage_bucket.locustfiles.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.ddos_runner.email}"
}