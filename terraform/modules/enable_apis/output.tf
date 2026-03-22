output "enabled_services" {
  description = "Map of enabled services"
  value       = {
    host       = google_project_service.host_project_services
    service    = google_project_service.service_project_services
  }
}