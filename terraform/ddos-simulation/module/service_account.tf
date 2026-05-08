resource "google_service_account" "ddos_runner" {
  project      = module.attacker_project.project.project_id
  account_id   = "ddos-runner"
  display_name = "DDoS simulation MIG runtime SA"
  description  = "Attached to every attacker/baseline VM. Allowed to access the internal CA secret and write logs/metrics."

  depends_on = [
    module.attacker_apis,
    module.attacker_platform_iam,
  ]
}

module "ddos_runner_observability_iam" {
  source = "../../modules/iam_policies"

  project_id = module.attacker_project.project.project_id
  bindings = [
    { role = "roles/logging.logWriter", member = "serviceAccount:${google_service_account.ddos_runner.email}" },
    { role = "roles/monitoring.metricWriter", member = "serviceAccount:${google_service_account.ddos_runner.email}" },
  ]

  depends_on = [google_service_account.ddos_runner]
}

resource "google_secret_manager_secret_iam_member" "ddos_runner_ca_secret_accessor" {
  project   = module.attacker_project.project.project_id
  secret_id = google_secret_manager_secret.internal_ca_cert.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ddos_runner.email}"
}