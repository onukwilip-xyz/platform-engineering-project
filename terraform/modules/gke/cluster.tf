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