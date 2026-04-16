resource "google_compute_address" "public_gateway" {
  name         = "istio-public-gateway-ip"
  project      = var.service_project_id
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_address" "private_gateway" {
  name         = "istio-private-gateway-ip"
  project      = var.service_project_id
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
}