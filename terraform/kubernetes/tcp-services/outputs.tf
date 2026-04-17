output "shared_vip_name" {
  description = "Name of the shared VIP static IP. Used in the GKE annotation networking.gke.io/load-balancer-ip-addresses by each database service."
  value       = google_compute_address.shared_vip.name
}

output "shared_vip_address" {
  description = "IP address of the shared VIP. Each consumer module uses this to create its own DNS A record."
  value       = google_compute_address.shared_vip.address
}