resource "null_resource" "netbird_routes" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_routes.sh"
    environment = {
      PAT_SECRET_ID  = var.netbird_pat_secret_id
      PROJECT_ID     = var.service_project_id
      NETBIRD_DOMAIN = var.netbird_domain
      PARAMETER_ID   = var.netbird_group_id_parameter_id
      ROUTES_JSON    = jsonencode(var.netbird_route_cidrs)
      IMPERSONATE_SA = var.tf_platform_sa_email
    }
  }

  triggers = {
    routes    = sha256(jsonencode(var.netbird_route_cidrs))
    setup_key = null_resource.netbird_setup_key.id
  }

  depends_on = [null_resource.netbird_setup_key]
}