resource "google_parameter_manager_parameter" "netbird_group_id" {
  provider = google.platform
  parameter_id = var.netbird_group_id_parameter_id
  project      = var.service_project_id
  format       = "UNFORMATTED"
}