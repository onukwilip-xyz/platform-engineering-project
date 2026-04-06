output "repositories" {
  description = "Map of created Artifact Registry repositories, keyed by the logical name provided in var.repositories."
  value       = google_artifact_registry_repository.repos
}