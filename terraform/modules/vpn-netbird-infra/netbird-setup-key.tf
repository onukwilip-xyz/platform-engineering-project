resource "null_resource" "netbird_setup_key" {
  # provider = google.platform
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_setup_key.sh"
    environment = {
      PAT_SECRET_ID       = var.netbird_pat_secret_id
      PROJECT_ID          = var.service_project_id
      NETBIRD_DOMAIN      = var.netbird_domain
      PARAMETER_ID        = var.netbird_group_id_parameter_id
      SETUP_KEY_NAME      = var.netbird_routing_peer_setup_key_name
      SETUP_KEY_SECRET_ID = var.netbird_routing_peer_setup_key_secret_id
      IMPERSONATE_SA = var.tf_platform_sa_email
    }
  }

  triggers = {
    group_resource = null_resource.netbird_group.id
  }

  depends_on = [null_resource.netbird_group]
}