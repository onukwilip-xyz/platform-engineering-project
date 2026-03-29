locals {
  network_user_members = merge(
    {
      tf_platform_sa   = "serviceAccount:${var.tf_platform_sa_email}"
      gke_robot_sa     = "serviceAccount:service-${var.service_project_number}@container-engine-robot.iam.gserviceaccount.com"
      cloudservices_sa = "serviceAccount:${var.service_project_number}@cloudservices.gserviceaccount.com"
    },
    { for i, v in var.extra_subnet_network_users : "extra_${i}" => v }
  )
}

resource "google_compute_subnetwork_iam_member" "subnet_network_user" {
  for_each = local.network_user_members

  project    = var.host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.gke_subnet.name

  role   = "roles/compute.networkUser"
  member = each.value

  depends_on = [ google_compute_shared_vpc_service_project.service ]
}