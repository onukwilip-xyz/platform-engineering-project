resource "google_compute_global_address" "public_gateway" {
  name         = "public-gateway-ip"
  project      = var.service_project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_address" "private_gateway" {
  name         = "private-gateway-ip"
  project      = var.service_project_id
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
}