resource "google_parameter_manager_parameter" "netbird_group_id" {
  provider     = google.platform
  parameter_id = var.netbird_group_id_parameter_id
  project      = var.service_project_id
  format       = "UNFORMATTED"
}

resource "null_resource" "netbird_group_id_cleanup" {
  triggers = {
    parameter_id = var.netbird_group_id_parameter_id
    project      = var.service_project_id
    sa_email     = var.tf_platform_sa_email
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/netbird_group_id_cleanup.sh"
    environment = {
      PARAMETER_ID   = self.triggers.parameter_id
      PROJECT_ID     = self.triggers.project
      IMPERSONATE_SA = self.triggers.sa_email
    }
  }

  depends_on = [google_parameter_manager_parameter.netbird_group_id]
}
