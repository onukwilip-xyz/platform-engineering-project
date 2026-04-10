resource "google_service_account" "node_sa" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.node_service_account_id
  display_name = var.node_service_account_display_name
}

# resource "google_service_account" "jump_sa" {
#   provider = google.platform

#   project      = var.service_project_id
#   account_id   = var.jump_service_account_id
#   display_name = var.jump_service_account_display_name
# }

# resource "google_service_account" "jump_vm_access_sa" {
#   provider = google.platform

#   project      = var.service_project_id
#   account_id   = var.jump_vm_access_service_account_id
#   display_name = var.jump_vm_access_service_account_display_name
# }