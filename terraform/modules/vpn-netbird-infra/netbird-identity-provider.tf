# Create Google Workspace identity provider in Netbird via the management API
resource "null_resource" "netbird_identity_provider" {
  count = var.enable_google_idp ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_netbird_idp.sh"
    environment = {
      PROJECT_ID                 = var.project_id
      NETBIRD_DOMAIN             = var.netbird_domain
      PAT_SECRET_ID              = var.netbird_pat_secret_id
      IDP_NAME                   = var.netbird_idp_name
      GOOGLE_OAUTH_CLIENT_ID     = var.google_oauth_client_id
      GOOGLE_OAUTH_CLIENT_SECRET = var.google_oauth_client_secret
      REDIRECT_URI_PARAMETER_ID  = var.netbird_idp_redirect_uri_parameter_id
      IMPERSONATE_SA             = var.impersonate_sa_email
    }
  }

  triggers = {
    netbird_domain = var.netbird_domain
    idp_name       = var.netbird_idp_name
    client_id      = var.google_oauth_client_id
  }

  depends_on = [
    null_resource.google_idp_validation,
    null_resource.wait_for_pat,
    null_resource.script_permissions,
    google_parameter_manager_parameter.netbird_idp_redirect_uri,
  ]
}