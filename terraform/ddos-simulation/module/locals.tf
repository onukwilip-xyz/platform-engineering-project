locals {
  # ── Shared VPC / target subnet (sourced from the host project's shared state) ──
  shared_vpc_host_project_id = data.terraform_remote_state.shared.outputs.host_project_id
  shared_vpc_self_link       = data.terraform_remote_state.shared.outputs.vpc_self_link
  subnet_name                = data.terraform_remote_state.shared.outputs.subnet_names[var.subnet_key]
  subnet_self_link           = data.terraform_remote_state.shared.outputs.subnet_self_links[var.subnet_key]

  private_dns_zone_name     = data.terraform_remote_state.shared.outputs.private_dns_zone.name
  private_dns_zone_dns_name = data.terraform_remote_state.shared.outputs.private_dns_zone.dns_name
  env_record_prefix         = var.environment == "production" ? "" : "${var.environment}."

  # target_public_ip = data.terraform_remote_state.gateway.outputs.public_gateway_global_ip
  target_public_ip = var.target_public_host

  # --- MIGs
  mig_configs = {
    attacker_hostname = {
      master_port      = "5557"
      locustfile       = "locustfile_attacker_hostname.py"
      target_size      = var.attacker_hostname_target_size
      role_label_value = "attacker-hostname"
    }
    attacker_ip = {
      master_port      = "5558"
      locustfile       = "locustfile_attacker_ip.py"
      target_size      = var.attacker_ip_target_size
      role_label_value = "attacker-ip"
    }
    baseline = {
      master_port      = "5559"
      locustfile       = "locustfile_baseline.py"
      target_size      = var.baseline_target_size
      role_label_value = "baseline"
    }
  }

  vm_labels = merge(var.labels, {
    gcp-product = "compute"
  })
}
