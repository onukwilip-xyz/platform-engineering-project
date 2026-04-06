output "service_project_id" {
  description = "The staging service project ID."
  value       = module.service_project.project.project_id
}

output "gke_cluster_name" {
  description = "The name of the staging GKE cluster."
  value       = module.gke.gke_cluster.name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the staging GKE cluster."
  value       = module.gke.gke_cluster.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the staging GKE cluster (pass to the cert-manager layer as cluster_ca_certificate)."
  value       = module.gke.gke_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}