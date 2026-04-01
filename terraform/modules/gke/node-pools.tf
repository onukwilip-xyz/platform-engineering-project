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

  initial_node_count = each.value.initial_node_count

  autoscaling {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge = try(each.value.max_surge, 1)
    max_unavailable = try(each.value.max_unavailable, 0)
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