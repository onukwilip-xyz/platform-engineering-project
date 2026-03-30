output "enabled_services" {
  description = "Map of enabled service resources."
  value       = google_project_service.services
}