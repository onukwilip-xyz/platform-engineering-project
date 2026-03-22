resource "null_resource" "netbird_route" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_route.sh"
    environment = {
      PAT_SECRET_ID  = var.netbird_pat_secret_id
      PROJECT_ID     = var.service_project_id
      NETBIRD_DOMAIN = var.netbird_domain
      PARAMETER_ID   = var.netbird_group_id_parameter_id
      VPC_CIDR       = var.vpc_subnet_cidr
    }
  }

  triggers = {
    vpc_cidr  = var.vpc_subnet_cidr
    setup_key = null_resource.netbird_setup_key.id
  }

  depends_on = [null_resource.netbird_setup_key]
}