resource "google_secret_manager_secret" "internal_ca_cert" {
  project   = module.attacker_project.project.project_id
  secret_id = var.internal_ca_secret_id

  replication {
    auto {}
  }

  labels = var.labels

  depends_on = [
    module.attacker_apis,
    module.attacker_platform_iam,
  ]
}

resource "google_secret_manager_secret_version" "internal_ca_cert" {
  secret      = google_secret_manager_secret.internal_ca_cert.id
  secret_data = local.internal_ca_cert_pem
}
