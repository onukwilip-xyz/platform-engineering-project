locals {
  internal_dns_domain = "${var.private_subdomain}.${var.subdomain}.${var.root_domain}"
}

resource "null_resource" "netbird_nameserver" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/create_nameservers.sh"
    environment = {
      PAT_SECRET_ID       = var.netbird_pat_secret_id
      PROJECT_ID          = var.project_id
      NETBIRD_DOMAIN      = var.netbird_domain
      SUBNETWORK_NAME     = var.subnetwork_name
      REGION              = var.region
      INTERNAL_DNS_DOMAIN = local.internal_dns_domain
      IMPERSONATE_SA      = var.impersonate_sa_email
    }
  }

  triggers = {
    domain      = local.internal_dns_domain
    subnetwork  = var.subnetwork_name
    region      = var.region
    # Re-run whenever routes are re-created (setup key refresh)
    routes      = null_resource.netbird_routes.id
  }

  depends_on = [null_resource.netbird_routes]
}