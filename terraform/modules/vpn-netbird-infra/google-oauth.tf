# Validates that OAuth credentials are provided when Google IdP is enabled
resource "null_resource" "google_idp_validation" {
  count = var.enable_google_idp ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.google_oauth_client_id != ""
      error_message = "google_oauth_client_id is required when enable_google_idp = true. See the module README.md for pre-requisite steps."
    }
    precondition {
      condition     = var.google_oauth_client_secret != ""
      error_message = "google_oauth_client_secret is required when enable_google_idp = true. See the module README.md for pre-requisite steps."
    }
    precondition {
      condition     = var.netbird_idp_redirect_uri_parameter_id != ""
      error_message = "netbird_idp_redirect_uri_parameter_id is required when enable_google_idp = true."
    }
  }
}