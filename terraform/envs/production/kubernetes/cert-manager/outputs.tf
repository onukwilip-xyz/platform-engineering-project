output "namespace" {
  description = "The cert-manager namespace. Consumed by the cert-manager-config unit."
  value       = module.cert_manager.namespace
}

output "cert_manager_dns_sa_email" {
  description = "Email of the GCP DNS-01 solver service account."
  value       = module.cert_manager.cert_manager_dns_sa_email
}