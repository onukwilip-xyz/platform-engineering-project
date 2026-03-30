# ──────────────────────────────────────────────
# Outputs consumed by environment layers via terraform_remote_state
# ──────────────────────────────────────────────

output "host_project_id" {
  description = "The host project ID."
  value       = module.host_project.project.project_id
}

output "vpc_self_link" {
  description = "Self-link of the Shared VPC network."
  value       = module.host_networking.vpc.self_link
}

output "gke_subnet_self_link" {
  description = "Self-link of the GKE subnet."
  value       = module.host_networking.gke_subnet.self_link
}

output "gke_subnet_name" {
  description = "Name of the GKE subnet."
  value       = module.host_networking.gke_subnet.name
}

output "gke_subnet_cidr" {
  description = "Primary CIDR of the GKE subnet (used for master_authorized_cidr)."
  value       = module.host_networking.gke_subnet.ip_cidr_range
}

output "pods_secondary_range_name" {
  description = "Secondary range name for pods."
  value       = module.host_networking.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Secondary range name for services."
  value       = module.host_networking.services_secondary_range_name
}

output "public_dns_zone" {
  description = "The public DNS managed zone."
  value       = module.dns.public_dns_zone
}

output "private_dns_zone" {
  description = "The private DNS managed zone."
  value       = module.dns.private_dns_zone
}