resource "google_compute_address" "cf_gateway_ip" {
  name         = local.ip_address_name
  project      = var.service_project_id
  region       = var.region
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}
