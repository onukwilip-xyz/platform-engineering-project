resource "null_resource" "netbird_setup_key" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_setup_key.sh"
    environment = {
      PAT_SECRET_ID       = var.netbird_pat_secret_id
      PROJECT_ID          = var.project_id
      NETBIRD_DOMAIN      = var.netbird_domain
      PARAMETER_ID        = var.netbird_group_id_parameter_id
      SETUP_KEY_NAME      = var.netbird_routing_peer_setup_key_name
      SETUP_KEY_SECRET_ID = var.netbird_routing_peer_setup_key_secret_id
      IMPERSONATE_SA      = var.impersonate_sa_email
    }
  }

  triggers = {
    group_resource = null_resource.netbird_group.id
  }

  depends_on = [null_resource.netbird_group]
}

resource "null_resource" "netbird_cicd_setup_key" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_setup_key.sh"
    environment = {
      # Common vars (shared with routing peer invocation)
      PAT_SECRET_ID  = var.netbird_pat_secret_id
      PROJECT_ID     = var.project_id
      NETBIRD_DOMAIN = var.netbird_domain
      IMPERSONATE_SA = var.impersonate_sa_email

      # Routing peer vars — required by the existing section of the script;
      # that section is idempotent (finds key in Secret Manager and exits early).
      PARAMETER_ID        = var.netbird_group_id_parameter_id
      SETUP_KEY_NAME      = var.netbird_routing_peer_setup_key_name
      SETUP_KEY_SECRET_ID = var.netbird_routing_peer_setup_key_secret_id

      # CI/CD vars — activate the new section prepended to the script.
      CICD_SETUP_KEY_NAME      = var.netbird_cicd_setup_key_name
      CICD_SETUP_KEY_SECRET_ID = var.netbird_cicd_setup_key_secret_id
    }
  }

  triggers = {
    cicd_setup_key_name = var.netbird_cicd_setup_key_name
  }

  depends_on = [
    google_secret_manager_secret.netbird_cicd_setup_key,
    null_resource.netbird_setup_key,
  ]
}