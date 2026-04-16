resource "google_compute_address" "public_gateway" {
  provider     = google.net
  name         = "istio-public-gateway-ip"
  project      = var.host_project_id
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_address" "private_gateway" {
  provider     = google.net
  name         = "istio-private-gateway-ip"
  project      = var.host_project_id
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
}