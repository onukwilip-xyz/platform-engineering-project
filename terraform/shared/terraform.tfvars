# ──────────────────────────────────────────────
# Provider / Auth
# ──────────────────────────────────────────────
tf_network_sa_email = "tf-network@pe-terraform-project.iam.gserviceaccount.com"
region              = "us-central1"
zone                = "us-central1-a"

# ──────────────────────────────────────────────
# Host Project
# ──────────────────────────────────────────────
org_id             = "256391743797"
host_project_name  = "pe-host-project"
billing_account_id = "01E4F5-FFA2DF-D86AC5"

# ──────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────
vpc_name    = "pe-shared-vpc"
subnet_name = "gke-subnet"
subnet_cidr = "10.10.0.0/20"
ssh_network_tag = "ssh"

pods_secondary_range_name     = "gke-pods-range"
pods_secondary_cidr           = "10.20.0.0/16"
services_secondary_range_name = "gke-services-range"
services_secondary_cidr       = "10.30.0.0/20"

# ──────────────────────────────────────────────
# DNS
# ──────────────────────────────────────────────
cloudflare_api_token = "cfut_ECHt20TQATXTcUR648ewZ8cK5011cKOw5BYJwYLe95ec21cc"
cloudflare_zone_id   = "622fa5a5eb070990767598786ddef562"
root_domain          = "onukwilip.xyz"
subdomain            = "pe"
private_subdomain    = "internal"

# ──────────────────────────────────────────────
# VPN Server Infrastructure
# ──────────────────────────────────────────────
netbird_server_instance_name               = "netbird-server"
netbird_domain                             = "netbird.pe.onukwilip.xyz"
dns_managed_zone_name                      = "pe-onukwilip-xyz"
letsencrypt_email                          = "onukwilip@onukwilip.xyz"
netbird_pat_secret_id                      = "netbird-pat"
netbird_server_service_account_id          = "netbird-server"
netbird_server_service_account_name        = "Netbird Server"
netbird_server_service_account_description = "Service account for Netbird server instance"
netbird_server_network_tag                 = "netbird-server"
netbird_admin_email                        = "onukwilip@gmail.com"
netbird_admin_password                     = "n3tb1rd*#"
netbird_admin_password_secret_id           = "netbird-admin-password"
netbird_service_user_name                  = "Terraform User"
netbird_service_user_token_name            = "Terraform Token"

# ──────────────────────────────────────────────
# VPN Netbird Routing Peer
# ──────────────────────────────────────────────
netbird_routing_peer_instance_name               = "netbird-routing-peer"
netbird_routing_peer_group_name                  = "routing-peers"
netbird_routing_peer_setup_key_name              = "routing-peer-setup-key"
netbird_routing_peer_setup_key_secret_id         = "netbird-vpn-routing-setup-key"
netbird_group_id_parameter_id                    = "netbird-vpn-routing-peer-group"
netbird_routing_peer_service_account_id          = "netbird-routing-peer"
netbird_routing_peer_service_account_name        = "Netbird Routing Peer"
netbird_routing_peer_service_account_description = "Service account for Netbird routing peer instance"

netbird_route_cidrs = [
  {
    cidr        = "10.10.0.0/20"
    network_id  = "vpc-subnet-route"
    description = "Route VPC subnet traffic through routing peer"
  },
  {
    cidr        = "172.16.0.0/28"
    network_id  = "gke-master-route"
    description = "Route GKE control plane traffic through routing peer"
  },
]

# ──────────────────────────────────────────────
# Google Workspace Identity Provider
# ──────────────────────────────────────────────
enable_google_idp                     = true
google_oauth_client_id                = "<placeholder>"
google_oauth_client_secret            = "<placeholder>"
netbird_idp_name                      = "Google Workspace"
netbird_idp_redirect_uri_parameter_id = "netbird-idp-redirect-uri"

# ──────────────────────────────────────────────
# Netbird User Invitations
# ──────────────────────────────────────────────
netbird_users = [
  { name = "Prince Onukwili", email = "onukwilip2006@gmail.com", role = "user" },
]