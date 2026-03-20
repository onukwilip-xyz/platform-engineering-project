module "projects" {
  source = "./modules/projects"
  providers = {
    google = google.net
  }

  org_id             = var.org_id
  host_project       = var.host_project
  service_project    = var.service_project
  billing_account_id = var.billing_account_id
}

module "iam_policies" {
  source = "./modules/iam_policies"
  providers = {
    google = google.net
  }

  host_project_id        = module.projects.host_project.project_id
  service_project_id     = module.projects.service_project.project_id
  service_project_number = module.projects.service_project.number
  tf_network_sa_email    = var.tf_network_sa_email
  tf_platform_sa_email   = var.tf_platform_sa_email
  region                 = var.region

  depends_on = [module.projects]
}

module "enable_apis" {
  source = "./modules/enable_apis"

  providers = {
    google.net      = google.net
    google.platform = google.platform
  }

  host_project    = module.projects.host_project.project_id
  service_project = module.projects.service_project.project_id

  depends_on = [module.iam_policies]
}

module "networking" {
  source = "./modules/networking"

  providers = {
    google = google.net
  }

  host_project_id        = module.projects.host_project.project_id
  service_project_id     = module.projects.service_project.project_id
  service_project_number = module.projects.service_project.number
  region                 = var.region

  vpc_name    = var.vpc_name
  subnet_name = var.subnet_name
  subnet_cidr = var.subnet_cidr

  pods_secondary_range_name     = var.pods_secondary_range_name
  pods_secondary_cidr           = var.pods_secondary_cidr
  services_secondary_range_name = var.services_secondary_range_name
  services_secondary_cidr       = var.services_secondary_cidr

  tf_platform_sa_email = var.tf_platform_sa_email

  depends_on = [module.enable_apis]
}

module "dns" {
  source = "./modules/dns"
  providers = {
    google     = google.net
    cloudflare = cloudflare
  }

  cloudflare_api_token = var.cloudflare_api_token
  root_domain          = var.root_domain
  subdomain            = var.subdomain
  private_subdomain    = var.private_subdomain
  private_dns_network  = module.networking.vpc.self_link
  cloudflare_zone_id   = var.cloudflare_zone_id
  host_project_id      = module.projects.host_project.project_id

  depends_on = [module.networking]
}

module "vpn_server_infra" {
  source = "./modules/vpn-server-infra"
  providers = {
    google.net      = google.net
    google.platform = google.platform
  }

  host_project_id = module.projects.host_project.project_id
  service_project_id = module.projects.service_project.project_id
  zone               = var.zone
  region             = var.region
  network            = module.networking.vpc.name
  subnetwork         = module.networking.gke_subnet.name

  netbird_server_instance_name       = var.netbird_server_instance_name
  netbird_domain                     = var.netbird_domain
  dns_managed_zone_name              = var.dns_managed_zone_name
  letsencrypt_email                  = var.letsencrypt_email
  netbird_pat_secret_id              = var.netbird_pat_secret_id

  depends_on = [module.dns]
}

module "vpn_netbird_infra" {
  source = "./modules/vpn-netbird-infra"
  providers = {
    google  = google.platform
    netbird = netbird
  }

  service_project_id = module.projects.service_project.project_id
  zone               = var.zone
  region             = var.region
  network            = module.networking.vpc.name
  subnetwork         = module.networking.gke_subnet.name

  netbird_routing_peer_instance_name = var.netbird_routing_peer_instance_name
  netbird_domain                     = var.netbird_domain
  netbird_routing_peer_setup_key_secret_id = var.netbird_routing_peer_setup_key_secret_id
  netbird_routing_peer_group_name          = var.netbird_routing_peer_group_name
  vpc_subnet_cidr                          = var.subnet_cidr
  netbird_routing_peer_setup_key_name      = var.netbird_routing_peer_setup_key_name

  depends_on = [module.vpn_server_infra]
}


# module "gke" {
#   source = "./modules/gke"
#   providers = {
#     google.net      = google.net
#     google.platform = google.platform
#   }

#   host_project_id        = module.projects.host_project.project_id
#   service_project_id     = module.projects.service_project.project_id
#   service_project_number = module.projects.service_project.number
#   region                 = var.region
#   zone                   = var.zone

#   network_self_link             = module.networking.vpc.self_link
#   subnet_self_link              = module.networking.gke_subnet.self_link
#   pods_secondary_range_name     = module.networking.pods_secondary_range_name
#   services_secondary_range_name = module.networking.services_secondary_range_name
#   subnet_name                   = module.networking.gke_subnet.name

#   cluster_name = var.gke_cluster_name
#   # Lock control-plane access down to the subnet CIDR (from networking)
#   master_authorized_cidr = module.networking.gke_subnet.ip_cidr_range
#   # Pick a non-overlapping /28 RFC1918 range for the control plane
#   master_ipv4_cidr_block = var.gke_master_ipv4_cidr_block
#   gke_resource_labels    = var.gke_resource_labels

#   node_service_account_id = var.gke_node_service_account_id

#   node_pools = [
#     {
#       name               = "large-node-pool"
#       machine_type       = "e2-standard-4"
#       initial_node_count = 0
#       min_node_count     = 0
#       max_node_count     = 5
#       labels             = {}
#       tags               = []
#       resource_labels = {
#         "type" = "large-node"
#         "team" = "platform-engineering"
#       }
#       taints = [
#         {
#           key    = "workload-type"
#           value  = "heavy"
#           effect = "NO_EXECUTE"
#         }
#       ]
#     },
#     {
#       name               = "small-node-pool"
#       machine_type       = "e2-standard-2"
#       initial_node_count = 0
#       min_node_count     = 0
#       max_node_count     = 5
#       labels             = {}
#       tags               = []
#       resource_labels = {
#         "type" = "small-node"
#         "team" = "platform-engineering"
#       }
#     }
#   ]

#   jump_service_account_id         = "jump-vm-sa"
#   jump_vm_name                    = "jump-vm"
#   jump_vm_access_sa_impersonators = ["user:onukwilip@onukwilip.xyz"]

#   depends_on = [module.networking]
# }
