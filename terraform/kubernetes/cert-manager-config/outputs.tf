output "internal_cluster_issuer_name" {
  description = "Name of the CA-backed ClusterIssuer for internal/VPC certificates."
  value       = var.internal_cluster_issuer_name
}

output "public_cluster_issuer_name" {
  description = "Name of the ACME ClusterIssuer for public internet-facing certificates."
  value       = var.public_cluster_issuer_name
}

output "internal_ca_cert_pem" {
  description = "PEM-encoded public certificate of the self-signed CA backing the internal ClusterIssuer. Consumed by external workloads (e.g. ddos-simulation MIGs) that need to verify TLS for *.private_domain hosts."
  value       = tls_self_signed_cert.ca.cert_pem
}