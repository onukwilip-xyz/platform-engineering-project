output "gke_cluster_name" {
  description = "Name of the GKE cluster."
  value       = module.gke.gke_cluster.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster API endpoint (raw IP). Consumed by the cert-manager unit's generated provider."
  value       = module.gke.gke_cluster.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "Base64-encoded GKE cluster CA cert. Consumed by the cert-manager unit's generated provider."
  value       = module.gke.gke_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "service_project_id" {
  description = "Service project ID. Re-exported for downstream units (cert-manager)."
  value       = var.service_project_id
}

output "host_project_id" {
  description = "Host project ID (from shared state). Re-exported as dns_project_id for cert-manager."
  value       = data.terraform_remote_state.shared.outputs.host_project_id
}