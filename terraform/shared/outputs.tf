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

output "infra_subnet_key" {
  description = "Key (subnet_name) in the subnet maps used for VPN/management infra — the source subnet for traffic routed through the Netbird routing peer (e.g. needs to be included in master_authorized_networks for private GKE clusters reached over the VPN)."
  value       = var.infra_subnet_key
}

output "subnet_self_link" {
  description = "Self-link of the staging subnet ('gke-subnet'). Kept for backward compatibility; see subnet_self_links for other subnets."
  value       = module.host_networking.subnets["gke-subnet"].self_link
}

output "subnet_name" {
  description = "Name of the staging subnet ('gke-subnet'). Kept for backward compatibility; see subnet_names for other subnets."
  value       = module.host_networking.subnets["gke-subnet"].name
}

output "subnet_cidr" {
  description = "Primary CIDR of the staging subnet ('gke-subnet', used for master_authorized_cidr). Kept for backward compatibility; see subnet_cidrs for other subnets."
  value       = module.host_networking.subnets["gke-subnet"].ip_cidr_range
}

output "pods_secondary_range_name" {
  description = "Pods secondary range name for the staging GKE subnet. Kept for backward compatibility; see pods_secondary_range_names for other subnets."
  value       = module.host_networking.pods_secondary_range_names["gke-subnet"]
}

output "services_secondary_range_name" {
  description = "Services secondary range name for the staging GKE subnet. Kept for backward compatibility; see services_secondary_range_names for other subnets."
  value       = module.host_networking.services_secondary_range_names["gke-subnet"]
}

output "subnet_self_links" {
  description = "Map of subnet_name => self_link, for all subnets in the shared VPC."
  value       = { for k, s in module.host_networking.subnets : k => s.self_link }
}

output "subnet_names" {
  description = "Map of subnet_name => name, for all subnets in the shared VPC."
  value       = { for k, s in module.host_networking.subnets : k => s.name }
}

output "subnet_cidrs" {
  description = "Map of subnet_name => primary CIDR, for all subnets in the shared VPC."
  value       = { for k, s in module.host_networking.subnets : k => s.ip_cidr_range }
}

output "pods_secondary_range_names" {
  description = "Map of subnet_name => pods secondary range name, for subnets that define one."
  value       = module.host_networking.pods_secondary_range_names
}

output "services_secondary_range_names" {
  description = "Map of subnet_name => services secondary range name, for subnets that define one."
  value       = module.host_networking.services_secondary_range_names
}

output "public_dns_zone" {
  description = "The public DNS managed zone."
  value       = module.dns.public_dns_zone
}

output "private_dns_zone" {
  description = "The private DNS managed zone."
  value       = module.dns.private_dns_zone
}