data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = var.shared_state_prefix
  }
}

locals {
  shared = data.terraform_remote_state.shared.outputs
}

module "gke" {
  source = "../../../modules/gke"
  providers = {
    google.net      = google.net
    google.platform = google.platform
  }

  host_project_id        = local.shared.host_project_id
  service_project_id     = var.service_project_id
  service_project_number = var.service_project_number
  region                 = var.region
  zone                   = var.zone

  monitoring_components = var.monitoring_components

  network_self_link             = local.shared.vpc_self_link
  subnet_self_link              = local.shared.subnet_self_links[var.subnet_key]
  pods_secondary_range_name     = local.shared.pods_secondary_range_names[var.subnet_key]
  services_secondary_range_name = local.shared.services_secondary_range_names[var.subnet_key]
  subnet_name                   = local.shared.subnet_names[var.subnet_key]

  cluster_name = var.cluster_name
  master_authorized_cidrs = [
    {
      cidr_block   = local.shared.subnet_cidrs[var.subnet_key]
      display_name = "gke-subnet"
    },
    {
      cidr_block   = local.shared.subnet_cidrs[local.shared.infra_subnet_key]
      display_name = "vpn-infra-subnet"
    },
  ]
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  labels                 = var.labels

  node_service_account_id = var.node_service_account_id
  node_pools              = var.node_pools

  jump_service_account_id         = var.jump_service_account_id
  jump_vm_name                    = var.jump_vm_name
  jump_vm_access_sa_impersonators = var.jump_vm_access_sa_impersonators
}
