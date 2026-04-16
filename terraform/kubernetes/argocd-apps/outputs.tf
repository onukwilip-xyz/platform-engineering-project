output "cnpg_operator_application_name" {
  description = "Name of the CNPG operator ArgoCD Application."
  value       = kubernetes_manifest.cnpg_operator.manifest.metadata.name
}

output "postgres_cluster_application_name" {
  description = "Name of the PostgreSQL cluster ArgoCD Application."
  value       = kubernetes_manifest.postgres_cluster.manifest.metadata.name
}
