# * Host project IAM policies for TF Network SA

resource "google_project_iam_member" "network_admin" {
    project = var.host_project_id
    member = "serviceAccount:${var.tf_network_sa_email}"
    role = "roles/compute.networkAdmin"
}

resource "google_project_iam_member" "service_usage_admin_host" {
    project = var.host_project_id
    member = "serviceAccount:${var.tf_network_sa_email}"
    role = "roles/serviceusage.serviceUsageAdmin"
}

resource "google_project_iam_member" "dns_admin" {
    project = var.host_project_id
    member  = "serviceAccount:${var.tf_network_sa_email}"
    role    = "roles/dns.admin"
}

# * Service project IAM policies for TF Platform SA

resource "google_project_iam_member" "container_admin" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/container.admin"
}

resource "google_project_iam_member" "instance_admin" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/compute.instanceAdmin.v1"
}

resource "google_project_iam_member" "service_account_creator" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/iam.serviceAccountAdmin"
}

resource "google_project_iam_member" "service_account_user" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/iam.serviceAccountUser"
}

resource "google_project_iam_member" "artifact_registry_admin" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/artifactregistry.admin"
}

resource "google_project_iam_member" "storage_admin" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/storage.admin"
}

resource "google_project_iam_member" "service_usage_admin_platform" {
    project = var.service_project_id
    member = "serviceAccount:${var.tf_platform_sa_email}"
    role = "roles/serviceusage.serviceUsageAdmin"
}

locals {
  default_compute_engine_sa = "${var.service_project_number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "logs_writer" {
    project = var.service_project_id
    member = "serviceAccount:${local.default_compute_engine_sa}"
    role = "roles/logging.logWriter"
}