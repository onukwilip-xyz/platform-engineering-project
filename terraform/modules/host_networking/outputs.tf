output "vpc" {
  description = "The VPC network resource."
  value       = google_compute_network.vpc
}

output "subnets" {
  description = "Map of subnet_name => subnetwork resource."
  value       = google_compute_subnetwork.subnet
}

output "pods_secondary_range_names" {
  description = "Map of subnet_name => pods secondary range name, for subnets that defined one."
  value = {
    for s in var.subnets : s.subnet_name => s.pods_secondary_range_name
    if s.pods_secondary_range_name != null
  }
}

output "services_secondary_range_names" {
  description = "Map of subnet_name => services secondary range name, for subnets that defined one."
  value = {
    for s in var.subnets : s.subnet_name => s.services_secondary_range_name
    if s.services_secondary_range_name != null
  }
}