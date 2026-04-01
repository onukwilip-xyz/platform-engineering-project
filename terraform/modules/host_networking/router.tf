resource "google_compute_router" "nat_router" {
  count   = var.enable_nat ? 1 : 0
  project = var.host_project_id
  region  = var.region
  name    = "${var.vpc_name}-router"
  network = google_compute_network.vpc.id
}