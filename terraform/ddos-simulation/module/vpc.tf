resource "google_compute_network" "attack" {
  project                 = module.attacker_project.project.project_id
  name                    = "attack-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [
    module.attacker_apis,
    module.attacker_platform_iam,
  ]
}

resource "google_compute_subnetwork" "attack" {
  project       = module.attacker_project.project.project_id
  name          = "attack-subnet"
  network       = google_compute_network.attack.id
  ip_cidr_range = var.attack_subnet_cidr
  region        = var.attack_region
}
