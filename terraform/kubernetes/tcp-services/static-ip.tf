resource "google_compute_address" "shared_vip" {
  name         = "tcp-services-shared-vip"
  project      = var.service_project_id
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
  purpose      = "SHARED_LOADBALANCER_VIP"
}