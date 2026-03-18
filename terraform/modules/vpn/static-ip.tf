resource "google_compute_address" "netbird_server" {
  name    = "${var.netbird_server_instance_name}-ip"
  project = var.project_id
  region  = var.region
}