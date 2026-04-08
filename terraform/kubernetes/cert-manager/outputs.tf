output "namespace" {
  description = "The cert-manager namespace name. Consumed by cert-manager-config to create the CA secret in the correct namespace."
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "cert_manager_dns_sa_email" {
  description = "Email of the GCP service account used by cert-manager for DNS-01 challenges."
  value       = google_service_account.cert_manager_dns.email
}