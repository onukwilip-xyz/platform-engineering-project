output "security_policy_name" {
  description = "Name of the Cloud Armor security policy. Consumed by the gateway unit's GCPBackendPolicy."
  value       = module.public_gateway_armor.security_policy_name
}

output "security_policy_id" {
  description = "Fully qualified ID of the security policy."
  value       = module.public_gateway_armor.security_policy_id
}