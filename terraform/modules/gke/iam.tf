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

resource "google_project_iam_member" "jump_vm_access_sa_cluster_admin" {
  provider = google.net

  project = var.service_project_id
  role    = "roles/container.clusterAdmin"
  member  = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"
}

# resource "google_iap_tunnel_instance_iam_member" "jump_vm_access_sa_iap_tunnel_accessor" {
#   provider = google.net

#   project = var.service_project_id
#   zone = var.zone
#   instance = google_compute_instance.jump.name
#   role = "roles/iap.tunnelResourceAccessor"
#   member = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"

#   depends_on = [ google_compute_instance.jump ]
# }

resource "google_project_iam_member" "jump_vm_access_sa_compute_instance_admin" {
  provider = google.net

  project = var.service_project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"
}

# resource "google_compute_instance_iam_member" "jump_vm_access_sa_oslogin" {
#   provider = google.net

#   project = var.service_project_id
#   zone = var.zone
#   instance_name = google_compute_instance.jump.name
#   role = "roles/compute.osLogin"
#   member = "serviceAccount:${google_service_account.jump_vm_access_sa.email}"

#   depends_on = [ google_compute_instance.jump ]
# }

resource "google_service_account_iam_binding" "jump_access_impersonators" {
  provider = google.net

  service_account_id = google_service_account.jump_vm_access_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = var.jump_vm_access_sa_impersonators

  depends_on = [ google_service_account.jump_vm_access_sa ]
}