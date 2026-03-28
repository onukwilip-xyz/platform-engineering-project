resource "google_compute_network" "vpc" {
  project                 = var.host_project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  host_project    = var.host_project_id
  service_project = var.service_project_id

  depends_on = [google_compute_shared_vpc_host_project.host]
}