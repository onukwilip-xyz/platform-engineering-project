output "vpc" {
  value = google_compute_network.vpc
}

output "gke_subnet" {
  value = google_compute_subnetwork.gke_subnet
}

output "pods_secondary_range_name" {
  value = var.pods_secondary_range_name
}

output "services_secondary_range_name" {
  value = var.services_secondary_range_name
}