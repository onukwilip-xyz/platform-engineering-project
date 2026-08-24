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
  description = "Email of the runtime SA attached to the master and every worker VM."
  value       = google_service_account.ddos_runner.email
}

output "master_instance_name" {
  description = "Name of the master VM. Use with `gcloud compute ssh <name> --zone=<zone>` for IAP debugging."
  value       = google_compute_instance.master.name
}

output "master_zone" {
  description = "Zone of the master VM (zonal resource — needed for gcloud commands)."
  value       = google_compute_instance.master.zone
}

output "master_nic0_internal_ip" {
  description = "Master's internal IP on the attack VPC. Workers connect here on the Locust master ports 5557/5558/5559."
  value       = google_compute_instance.master.network_interface[0].network_ip
}

output "master_nic1_internal_ip" {
  description = "Master's internal IP on the host's GKE subnet. The ddos-plane DNS A record points here; operator browses Locust UIs at ddos-plane.<private_domain>:{8089,8090,8091}."
  value       = google_compute_address.master_nic1.address
}

output "ddos_plane_fqdn" {
  description = "Fully qualified DNS name (no trailing dot) where the Locust web UIs are reachable. Browse :8089 / :8090 / :8091 over NetBird."
  value       = trimsuffix(google_dns_record_set.ddos_plane.name, ".")
}

output "ddos_plane_urls" {
  description = "Direct URLs for the three Locust web UIs."
  value = {
    attacker_hostname = "http://${trimsuffix(google_dns_record_set.ddos_plane.name, ".")}:8089"
    attacker_ip       = "http://${trimsuffix(google_dns_record_set.ddos_plane.name, ".")}:8090"
    baseline          = "http://${trimsuffix(google_dns_record_set.ddos_plane.name, ".")}:8091"
  }
}

output "locustfiles_bucket_name" {
  description = "Name of the GCS bucket holding the rendered locustfiles. Edit + re-apply to push new versions; running workers pick them up only on next instance recycle."
  value       = google_storage_bucket.locustfiles.name
}

output "mig_self_links" {
  description = "Map of mig_label => MIG self link. Use for `gcloud compute instance-groups managed list-instances`."
  value       = { for k, m in google_compute_instance_group_manager.mig : k => m.self_link }
}

output "instance_template_self_links" {
  description = "Map of mig_label => instance template self link."
  value       = { for k, t in google_compute_instance_template.mig : k => t.self_link }
}