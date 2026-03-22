locals {
  host_services_list = concat([
    "container.googleapis.com",
    "compute.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "dns.googleapis.com"
  ], var.extra_host_services)

  service_services_list = concat([
    "container.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "parametermanager.googleapis.com",

    # Nice-to-have for your setup:
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iap.googleapis.com"
  ], var.extra_service_services)

  host_services    = toset(local.host_services_list)
  service_services = toset(local.service_services_list)
}

resource "google_project_service" "host_project_services" {
  provider = google.net

  for_each           = local.host_services
  project            = var.host_project
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "service_project_services" {
  provider = google.platform

  for_each           = local.service_services
  project            = var.service_project
  service            = each.value
  disable_on_destroy = false
}
