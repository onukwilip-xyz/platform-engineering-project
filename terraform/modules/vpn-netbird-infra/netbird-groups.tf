resource "null_resource" "netbird_group" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_group.sh"
    environment = {
      PAT_SECRET_ID  = var.netbird_pat_secret_id
      PROJECT_ID     = var.service_project_id
      NETBIRD_DOMAIN = var.netbird_domain
      GROUP_NAME     = var.netbird_routing_peer_group_name
      PARAMETER_ID   = var.netbird_group_id_parameter_id
    }
  }

  triggers = {
    domain     = var.netbird_domain
    group_name = var.netbird_routing_peer_group_name
  }

  depends_on = [
    null_resource.wait_for_pat,
    google_parameter_manager_parameter.netbird_group_id
  ]
}
