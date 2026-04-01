resource "google_compute_router_nat" "nat" {
  count   = var.enable_nat ? 1 : 0
  project = var.host_project_id
  region  = var.region
  name    = "${var.vpc_name}-nat"
  router  = google_compute_router.nat_router[0].name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}