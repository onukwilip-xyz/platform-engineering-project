resource "google_compute_subnetwork" "subnet" {
  for_each = { for s in var.subnets : s.subnet_name => s }

  project                  = var.host_project_id
  region                   = var.region
  name                     = each.value.subnet_name
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = each.value.subnet_cidr
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.pods_secondary_range_name != null ? [1] : []
    content {
      range_name    = each.value.pods_secondary_range_name
      ip_cidr_range = each.value.pods_secondary_cidr
    }
  }

  dynamic "secondary_ip_range" {
    for_each = each.value.services_secondary_range_name != null ? [1] : []
    content {
      range_name    = each.value.services_secondary_range_name
      ip_cidr_range = each.value.services_secondary_cidr
    }
  }
}