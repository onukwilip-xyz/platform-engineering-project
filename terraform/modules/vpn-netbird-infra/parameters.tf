# Parameter Manager parameter for storing the Netbird group ID
resource "google_parameter_manager_parameter" "netbird_group_id" {
  parameter_id = var.netbird_group_id_parameter_id
  project      = var.project_id
  format       = "UNFORMATTED"
}

# Parameter Manager parameter for storing the Netbird IdP redirect URI
resource "google_parameter_manager_parameter" "netbird_idp_redirect_uri" {
  count        = var.enable_google_idp ? 1 : 0
  parameter_id = var.netbird_idp_redirect_uri_parameter_id
  project      = var.project_id
  format       = "UNFORMATTED"
}

resource "null_resource" "netbird_group_id_cleanup" {
  triggers = {
    parameter_id = var.netbird_group_id_parameter_id
    project      = var.project_id
    sa_email     = var.impersonate_sa_email
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/parameters_versions_cleanup.sh"
    environment = {
      PARAMETER_ID   = self.triggers.parameter_id
      PROJECT_ID     = self.triggers.project
      IMPERSONATE_SA = self.triggers.sa_email
    }
  }

  depends_on = [google_parameter_manager_parameter.netbird_group_id]
}

resource "null_resource" "netbird_idp_redirect_uri_cleanup" {
  count = var.enable_google_idp ? 1 : 0
  triggers = {
    parameter_id = var.netbird_idp_redirect_uri_parameter_id
    project      = var.project_id
    sa_email     = var.impersonate_sa_email
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/parameters_versions_cleanup.sh"
    environment = {
      PARAMETER_ID   = self.triggers.parameter_id
      PROJECT_ID     = self.triggers.project
      IMPERSONATE_SA = self.triggers.sa_email
    }
  }

  depends_on = [google_parameter_manager_parameter.netbird_idp_redirect_uri]
}