resource "google_compute_network" "vpc" {
  project                 = var.host_project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}