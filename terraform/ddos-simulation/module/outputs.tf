output "attacker_project_id" {
  description = "ID of the attacker project. Useful for `gcloud --project=<id>` ops, kill-switch terragrunt apply, and post-test cleanup."
  value       = module.attacker_project.project.project_id
}

output "attacker_project_number" {
  description = "Number of the attacker project. Used by host-side IAM bindings that target the default Compute SA."
  value       = module.attacker_project.project.number
}

output "attack_vpc_self_link" {
  description = "Self link of the standalone attack VPC."
  value       = google_compute_network.attack.self_link
}

output "ddos_runner_sa_email" {
  description = "Email of the runtime SA attached to every MIG VM."
  value       = google_service_account.ddos_runner.email
}

output "internal_ca_secret_id" {
  description = "Resource ID of the GSM secret holding the internal CA cert."
  value       = google_secret_manager_secret.internal_ca_cert.id
}

output "mig_self_links" {
  description = "Map of mig_label => MIG self link. Use for `gcloud compute instance-groups managed list-instances`."
  value       = { for k, m in google_compute_region_instance_group_manager.mig : k => m.self_link }
}

output "instance_template_self_links" {
  description = "Map of mig_label => instance template self link."
  value       = { for k, t in google_compute_instance_template.mig : k => t.self_link }
}