output "gke_cluster" {
  value = google_container_cluster.gke_cluster
}

output "node_service_account" {
  value = google_service_account.node_sa
}

# output "jump_service_account" {
#   value = google_service_account.jump_sa
# }