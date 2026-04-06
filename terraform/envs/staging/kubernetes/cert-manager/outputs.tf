output "internal_cluster_issuer_name" {
  description = "Name of the CA-backed ClusterIssuer for internal certificates."
  value       = var.internal_cluster_issuer_name
}

output "public_cluster_issuer_name" {
  description = "Name of the ACME ClusterIssuer for public internet-facing certificates."
  value       = var.public_cluster_issuer_name
}