resource "google_compute_router_nat" "nat" {
  project = module.attacker_project.project.project_id
  region  = var.attack_region
  name    = "attack-vpc-nat"
  router  = google_compute_router.nat_router.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.attack.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}