output "security_policy_name" {
  description = "Name of the Cloud Armor security policy. Referenced by GCPBackendPolicy.spec.default.securityPolicy on the gateway unit."
  value       = google_compute_security_policy.this.name
}

output "security_policy_id" {
  description = "Fully qualified ID of the Cloud Armor security policy (projects/.../global/securityPolicies/...)."
  value       = google_compute_security_policy.this.id
}

output "security_policy_self_link" {
  description = "Self link of the Cloud Armor security policy."
  value       = google_compute_security_policy.this.self_link
}