resource "google_compute_router" "nat_router" {
  project = module.attacker_project.project.project_id
  region  = var.attack_region
  name    = "attack-vpc-router"
  network = google_compute_network.attack.id
}