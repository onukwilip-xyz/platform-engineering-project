locals {
  # Shared VPC / GKE subnet — sourced from the host project's shared state.
  shared_vpc_host_project_id = data.terraform_remote_state.shared.outputs.host_project_id
  shared_vpc_self_link       = data.terraform_remote_state.shared.outputs.vpc_self_link
  gke_subnet_name            = data.terraform_remote_state.shared.outputs.gke_subnet_name
  gke_subnet_self_link       = data.terraform_remote_state.shared.outputs.gke_subnet_self_link

  # Target endpoints — sourced from the gateway unit's state.
  target_public_ip   = data.terraform_remote_state.gateway.outputs.public_gateway_global_ip
  private_gateway_ip = data.terraform_remote_state.gateway.outputs.private_gateway_ip

  # CA cert — sourced from cert-manager-config.
  internal_ca_cert_pem = data.terraform_remote_state.cert_manager_config.outputs.internal_ca_cert_pem
}