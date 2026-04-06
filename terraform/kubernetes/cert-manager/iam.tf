resource "google_service_account" "cert_manager_dns" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.cert_manager_google_service_account_id
  display_name = "cert-manager ACME DNS-01 solver"
  description  = "Impersonated via Workload Identity by the cert-manager controller to manage Cloud DNS TXT records for ACME DNS-01 challenges."
}

resource "google_project_iam_member" "cert_manager_dns_admin" {
  provider = google.net

  project = var.dns_project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager_dns.email}"
}

resource "google_service_account_iam_member" "cert_manager_workload_identity" {
  provider = google.platform

  service_account_id = google_service_account.cert_manager_dns.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.service_project_id}.svc.id.goog[${var.namespace}/${var.cert_manager_k8s_service_account_name}]"
}
