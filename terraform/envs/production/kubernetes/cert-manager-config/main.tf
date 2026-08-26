module "cert_manager_config" {
  source = "../../../../kubernetes/cert-manager-config"

  providers = {
    kubernetes = kubernetes
    tls        = tls
  }

  cert_manager_namespace       = var.cert_manager_namespace
  dns_project_id               = var.dns_project_id
  ca_organization              = var.ca_organization
  ca_common_name               = var.ca_common_name
  internal_cluster_issuer_name = var.internal_cluster_issuer_name
  public_cluster_issuer_name   = var.public_cluster_issuer_name
  acme_email                   = var.acme_email
  acme_server                  = var.acme_server
}