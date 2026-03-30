output "vpc" {
  description = "The VPC network resource."
  value       = google_compute_network.vpc
}

output "gke_subnet" {
  description = "The GKE subnet resource."
  value       = google_compute_subnetwork.gke_subnet
}

output "pods_secondary_range_name" {
  description = "The name of the pods secondary IP range."
  value       = var.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "The name of the services secondary IP range."
  value       = var.services_secondary_range_name
}