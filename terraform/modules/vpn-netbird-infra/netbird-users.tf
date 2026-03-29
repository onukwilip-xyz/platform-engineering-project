# Create users in Netbird and send invitations
resource "null_resource" "netbird_users" {
  count = length(var.netbird_users) > 0 ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_netbird_users.sh"
    environment = {
      PROJECT_ID     = var.service_project_id
      NETBIRD_DOMAIN = var.netbird_domain
      PAT_SECRET_ID  = var.netbird_pat_secret_id
      USERS_JSON     = jsonencode(var.netbird_users)
      IMPERSONATE_SA = var.tf_platform_sa_email
    }
  }

  triggers = {
    users = sha256(jsonencode(var.netbird_users))
  }

  depends_on = [
    null_resource.wait_for_pat,
    null_resource.script_permissions,
  ]
}