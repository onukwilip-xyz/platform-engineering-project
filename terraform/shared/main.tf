# ──────────────────────────────────────────────
# Host Project
# ──────────────────────────────────────────────
module "host_project" {
  source = "../modules/projects"

  org_id             = var.org_id
  project_name       = var.host_project_name
  billing_account_id = var.billing_account_id
  labels             = merge(var.labels, { purpose = "host-project" })
}

# ──────────────────────────────────────────────
# Host Project IAM
# ──────────────────────────────────────────────
module "host_iam" {
  source = "../modules/iam_policies"

  project_id = module.host_project.project.project_id
  bindings = [
    # Networking
    {
      role   = "roles/compute.networkAdmin",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/serviceusage.serviceUsageAdmin",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/dns.admin",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    # VPN infrastructure
    {
      role   = "roles/compute.instanceAdmin.v1",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/iam.serviceAccountAdmin",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/iam.serviceAccountUser",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/secretmanager.admin",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/parametermanager.admin",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
    {
      role   = "roles/logging.logWriter",
      member = "serviceAccount:${var.tf_network_sa_email}"
    },
  ]

  depends_on = [module.host_project]
}

# ──────────────────────────────────────────────
# Host Project APIs
# ──────────────────────────────────────────────
module "host_apis" {
  source = "../modules/enable_apis"

  project_id = module.host_project.project.project_id
  services = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "dns.googleapis.com",
    # Required for VPN infrastructure
    "secretmanager.googleapis.com",
    "parametermanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iap.googleapis.com",
  ]

  depends_on = [module.host_iam]
}

# ──────────────────────────────────────────────
# Host Networking (VPC, Subnets, NAT, Firewall)
# ──────────────────────────────────────────────
module "host_networking" {
  source = "../modules/host_networking"

  host_project_id = module.host_project.project.project_id
  region          = var.region

  vpc_name    = var.vpc_name
  subnet_name = var.subnet_name
  subnet_cidr = var.subnet_cidr

  pods_secondary_range_name     = var.pods_secondary_range_name
  pods_secondary_cidr           = var.pods_secondary_cidr
  services_secondary_range_name = var.services_secondary_range_name
  services_secondary_cidr       = var.services_secondary_cidr
  

  ssh_network_tag = var.ssh_network_tag

  depends_on = [module.host_apis]
}

# ──────────────────────────────────────────────
# DNS (Public + Private zones, Cloudflare NS delegation)
# ──────────────────────────────────────────────
module "dns" {
  source = "../modules/dns"
  providers = {
    google     = google
    cloudflare = cloudflare
  }

  host_project_id      = module.host_project.project.project_id
  private_dns_network  = module.host_networking.vpc.self_link
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  root_domain          = var.root_domain
  subdomain            = var.subdomain
  private_subdomain    = var.private_subdomain
  labels               = var.labels

  depends_on = [module.host_networking]
}

# ──────────────────────────────────────────────
# VPN Server Infrastructure (Netbird management server)
# ──────────────────────────────────────────────
module "vpn_server_infra" {
  source = "../modules/vpn-server-infra"

  project_id = module.host_project.project.project_id
  zone       = var.zone
  region     = var.region
  network    = module.host_networking.vpc.self_link
  subnetwork = module.host_networking.gke_subnet.self_link

  netbird_server_instance_name               = var.netbird_server_instance_name
  netbird_domain                             = var.netbird_domain
  dns_managed_zone_name                      = var.dns_managed_zone_name
  letsencrypt_email                          = var.letsencrypt_email
  netbird_pat_secret_id                      = var.netbird_pat_secret_id
  netbird_server_service_account_id          = var.netbird_server_service_account_id
  netbird_server_service_account_name        = var.netbird_server_service_account_name
  netbird_server_service_account_description = var.netbird_server_service_account_description
  ssh_network_tag                            = var.ssh_network_tag
  netbird_server_network_tag                 = var.netbird_server_network_tag
  netbird_admin_email                        = var.netbird_admin_email
  netbird_admin_password                     = var.netbird_admin_password
  netbird_admin_password_secret_id           = var.netbird_admin_password_secret_id
  netbird_service_user_name                  = var.netbird_service_user_name
  netbird_service_user_token_name            = var.netbird_service_user_token_name
  labels                                     = var.labels

  depends_on = [
    module.dns,
    module.host_iam,
  ]
}

# ──────────────────────────────────────────────
# VPN Netbird Infrastructure (routing peer, groups, routes)
# ──────────────────────────────────────────────
module "vpn_netbird_infra" {
  source = "../modules/vpn-netbird-infra"

  project_id = module.host_project.project.project_id
  zone       = var.zone
  region     = var.region
  network    = module.host_networking.vpc.self_link
  subnetwork = module.host_networking.gke_subnet.self_link

  ssh_network_tag = var.ssh_network_tag

  netbird_routing_peer_instance_name               = var.netbird_routing_peer_instance_name
  netbird_domain                                   = var.netbird_domain
  netbird_routing_peer_setup_key_secret_id         = var.netbird_routing_peer_setup_key_secret_id
  netbird_routing_peer_group_name                  = var.netbird_routing_peer_group_name
  netbird_route_cidrs                              = var.netbird_route_cidrs
  netbird_routing_peer_setup_key_name              = var.netbird_routing_peer_setup_key_name
  netbird_pat_secret_id                            = module.vpn_server_infra.netbird_pat_secret.secret_id
  netbird_group_id_parameter_id                    = var.netbird_group_id_parameter_id
  netbird_routing_peer_service_account_id          = var.netbird_routing_peer_service_account_id
  netbird_routing_peer_service_account_name        = var.netbird_routing_peer_service_account_name
  netbird_routing_peer_service_account_description = var.netbird_routing_peer_service_account_description
  impersonate_sa_email                             = var.tf_network_sa_email

  # Google Workspace Identity Provider
  enable_google_idp                     = var.enable_google_idp
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  netbird_idp_name                      = var.netbird_idp_name
  netbird_idp_redirect_uri_parameter_id = var.netbird_idp_redirect_uri_parameter_id

  # User invitations
  netbird_users = var.netbird_users
  labels        = var.labels

  # Internal DNS nameserver group
  root_domain       = var.root_domain
  subdomain         = var.subdomain
  private_subdomain = var.private_subdomain
  subnetwork_name   = module.host_networking.gke_subnet.name

  depends_on = [
    module.host_networking, # DNS inbound policy must exist before create_nameservers.sh runs
    module.vpn_server_infra,
    module.host_iam,
  ]
}
