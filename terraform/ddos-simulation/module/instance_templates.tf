locals {
  mig_configs = {
    attacker_hostname = {
      region        = var.attack_region
      attack_subnet = google_compute_subnetwork.attack_primary.self_link
      target_host   = var.target_public_host
      write_rps     = var.attacker_write_rps
      read_rps      = var.attacker_read_rps
      target_size   = var.attacker_hostname_target_size
      use_ip_target = false
    }
    attacker_ip = {
      region        = var.attack_region
      attack_subnet = google_compute_subnetwork.attack_primary.self_link
      target_host   = local.target_public_ip
      write_rps     = var.attacker_write_rps
      read_rps      = var.attacker_read_rps
      target_size   = var.attacker_ip_target_size
      use_ip_target = true
    }
    baseline = {
      region        = var.baseline_region
      attack_subnet = google_compute_subnetwork.attack_baseline.self_link
      target_host   = var.target_public_host
      write_rps     = var.baseline_write_rps
      read_rps      = var.baseline_read_rps
      target_size   = var.baseline_target_size
      use_ip_target = false
    }
  }

  vm_labels = merge(var.labels, {
    purpose     = "ddos-simulation"
    gcp-product = "compute"
  })
}

resource "google_compute_instance_template" "mig" {
  for_each = local.mig_configs

  project     = module.attacker_project.project.project_id
  name_prefix = "ddos-${replace(each.key, "_", "-")}-"
  description = "Instance template for ${each.key} MIG (DDoS simulation)"

  machine_type   = var.machine_type
  can_ip_forward = false
  region         = each.value.region

  tags = [
    var.ssh_network_tag,
    var.metrics_egress_network_tag,
  ]

  labels = merge(local.vm_labels, { mig = replace(each.key, "_", "-") })

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  # nic0: standalone attack VPC, ephemeral public IP on Premium tier.
  # All attack/baseline egress traffic to the public Gateway flows out here.
  network_interface {
    network    = google_compute_network.attack.id
    subnetwork = each.value.attack_subnet

    access_config {
      network_tier = "PREMIUM"
    }
  }

  # nic1: Shared VPC GKE subnet, no public IP. Carries metrics traffic
  # (e.g. Prometheus remote-write) to the private gateway IP.
  network_interface {
    network    = local.shared_vpc_self_link
    subnetwork = local.gke_subnet_self_link
  }

  metadata = {
    target_host               = each.value.target_host
    target_uses_ip            = each.value.use_ip_target ? "true" : "false"
    target_host_header        = var.target_public_host
    prometheus_ip             = local.private_gateway_ip
    prometheus_metrics_host   = var.private_gateway_metrics_host
    write_rps                 = tostring(each.value.write_rps)
    read_rps                  = tostring(each.value.read_rps)
    test_duration             = var.test_duration
    mig_label                 = each.key
    ca_secret_resource        = google_secret_manager_secret.internal_ca_cert.id
    ca_secret_name            = google_secret_manager_secret.internal_ca_cert.secret_id
    enable-oslogin            = "TRUE"
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
    startup-script            = templatefile("${path.module}/scripts/startup.sh.tftpl", {})
  }

  service_account {
    email  = google_service_account.ddos_runner.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_compute_subnetwork_iam_member.ddos_runner_network_user,
    google_compute_subnetwork_iam_member.attacker_compute_sa_network_user,
    google_secret_manager_secret_iam_member.ddos_runner_ca_secret_accessor,
  ]
}