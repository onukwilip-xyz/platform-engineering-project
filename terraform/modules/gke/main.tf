
# Grant GKE Service Account Secuirity Admin and Host Service Agent User on host project so it can manage firewall rules for private cluster
locals {
  gke_sa = "serviceAccount:service-${var.service_project_number}@container-engine-robot.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "gke_sa_security_admin_on_host" {
  provider = google.net

  project = var.host_project_id
  role    = "roles/compute.securityAdmin"
  member  = local.gke_sa
}

resource "google_project_iam_member" "gke_sa_host_service_agent_user_on_host" {
  provider = google.net

  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = local.gke_sa
}

############################
# Service Accounts
############################

resource "google_service_account" "node_sa" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.node_service_account_id
  display_name = var.node_service_account_display_name
}

# Grant minimum required for nodepool SAs in GKE and any extra roles specified in variable.
resource "google_project_iam_member" "node_sa_min_role" {
  provider = google.net

  project = var.service_project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# Grant the Nodepool SA the "Compute Network User" role on the subnet so it can create necessary network interfaces for nodes.
resource "google_compute_subnetwork_iam_member" "node_sa_network_user" {
  provider = google.net

  project    = var.host_project_id
  region     = var.region
  subnetwork = var.subnet_name

  role   = "roles/compute.networkUser"
  member = "serviceAccount:${google_service_account.node_sa.email}"
}

resource "google_project_iam_member" "node_sa_extra_roles" {
  provider = google.net
  for_each = toset(var.node_service_account_extra_roles)

  project = var.service_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

# Create and the jump VM SA and its access SA, and give it GKE Cluster Admin access so it can get-credentials & administer cluster access.
resource "google_service_account" "jump_sa" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.jump_service_account_id
  display_name = var.jump_service_account_display_name
}

resource "google_project_iam_member" "jump_sa_logs_writer" {
  provider = google.net
  project  = var.service_project_id
  role     = "roles/logging.logWriter"
  member   = "serviceAccount:${google_service_account.jump_sa.email}"
}

resource "google_project_iam_member" "jump_sa_metric_writer" {
  provider = google.net
  project  = var.service_project_id
  role     = "roles/monitoring.metricWriter"
  member   = "serviceAccount:${google_service_account.jump_sa.email}"
}

resource "google_service_account_iam_member" "jump_sa_actas_for_access_sa" {
  provider = google.net
  service_account_id = google_service_account.jump_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"
}

resource "google_service_account" "jump_vm_access_sa" {
  provider = google.platform

  project      = var.service_project_id
  account_id   = var.jump_vm_access_service_account_id
  display_name = var.jump_vm_access_service_account_display_name
}

resource "google_project_iam_member" "jump_vm_access_sa_cluster_admin" {
  provider = google.net

  project = var.service_project_id
  role    = "roles/container.clusterAdmin"
  member  = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"
}

############################
# GKE Cluster (regional, private)
############################

resource "google_container_cluster" "gke_cluster" {
  provider = google.platform

  project  = var.service_project_id
  name     = var.cluster_name
  location = var.region

  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  networking_mode = "VPC_NATIVE"


  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  release_channel {
    channel = var.release_channel
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = false
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.master_authorized_cidr
      display_name = "gke-subnet-only"
    }

    private_endpoint_enforcement_enabled = true
  }

  workload_identity_config {
    workload_pool = "${var.service_project_id}.svc.id.goog"
  }

  vertical_pod_autoscaling {
    enabled = var.enable_vpa
  }

  # Logging: keep control plane/system logs, disable workload/container logs by not including WORKLOADS.
  # Supported values include SYSTEM_COMPONENTS, APISERVER, CONTROLLER_MANAGER, SCHEDULER, WORKLOADS.
  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  cost_management_config {
    enabled = var.enable_cost_management
  }

  deletion_protection = var.deletion_protection
  resource_labels     = var.gke_resource_labels

  depends_on = [
    google_project_iam_member.gke_sa_host_service_agent_user_on_host,
    google_project_iam_member.gke_sa_security_admin_on_host,
  ]
}

############################
# Node Pools
############################

locals {
  node_pools_by_name = {
    for np in var.node_pools : np.name => np
  }
}

resource "google_container_node_pool" "pools" {
  provider = google.platform
  for_each = local.node_pools_by_name

  project  = var.service_project_id
  name     = each.value.name
  location = var.region
  cluster  = google_container_cluster.gke_cluster.name

  # In regional clusters, this is per-zone
  initial_node_count = each.value.initial_node_count

  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_type       = var.node_disk_type
    disk_size_gb    = var.node_disk_size_gb
    image_type      = var.node_image_type
    service_account = google_service_account.node_sa.email

    oauth_scopes = var.node_oauth_scopes

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = merge(
      var.common_node_labels,
      try(each.value.labels, {})
    )

    tags            = length(try(each.value.tags, [])) > 0 ? each.value.tags : var.node_network_tags
    resource_labels = each.value.resource_labels

    dynamic "taint" {
      for_each = try(each.value.taints, [])
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }
}

############################
# Jump VM (no external IP)
############################

resource "google_compute_firewall" "allow_iap_to_jump" {
  provider = google.net

  project = var.host_project_id
  name    = var.jump_vm_iap_firewall_name
  network = var.network_self_link

  direction     = "INGRESS"
  source_ranges = var.jump_vm_iap_source_ranges
  target_tags   = var.jump_vm_iap_target_tags

  allow {
    protocol = "tcp"
    ports    = var.jump_vm_iap_tcp_ports
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_instance" "jump" {
  provider = google.platform

  project      = var.service_project_id
  name         = var.jump_vm_name
  zone         = var.zone
  machine_type = var.jump_vm_machine_type
  tags         = var.jump_vm_network_tags

  boot_disk {
    initialize_params {
      image = var.jump_vm_image
      size  = var.jump_vm_boot_disk_size_gb
      type  = var.jump_vm_boot_disk_type
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link
  }

  service_account {
    email  = google_service_account.jump_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = merge(
    var.jump_vm_metadata,
    {
      enable-oslogin = var.jump_vm_enable_oslogin ? "TRUE" : "FALSE"
      startup-script = file("${path.module}/scripts/tinyproxy_startup.sh")
    }
  )
}

# Grant the Jump VM accessor SA permissions to connect to the Jump VM via IAP Tunnel

resource "google_iap_tunnel_instance_iam_member" "jump_vm_access_sa_iap_tunnel_accessor" {
  provider = google.net

  project = var.service_project_id
  zone = var.zone
  instance = google_compute_instance.jump.name
  role = "roles/iap.tunnelResourceAccessor"
  member = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"

  depends_on = [ google_compute_instance.jump ]
}

resource "google_project_iam_member" "jump_vm_access_sa_compute_instance_admin" {
  provider = google.net

  project = var.service_project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"
}

resource "google_compute_instance_iam_member" "jump_vm_access_sa_oslogin" {
  provider = google.net

  project = var.service_project_id
  zone = var.zone
  instance_name = google_compute_instance.jump.name
  role = "roles/compute.osLogin"
  member = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"

  depends_on = [ google_compute_instance.jump ]
}

resource "google_service_account_iam_binding" "jump_access_impersonators" {
  provider = google.net

  service_account_id = google_service_account.jump_vm_access_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = var.jump_vm_access_sa_impersonators

  depends_on = [ google_service_account.jump_vm_access_sa ]
}