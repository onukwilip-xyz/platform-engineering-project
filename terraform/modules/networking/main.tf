resource "google_compute_network" "vpc" {
  project                 = var.host_project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "gke_subnet" {
  project                  = var.host_project_id
  region                   = var.region
  name                     = var.subnet_name
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pods_secondary_range_name
    ip_cidr_range = var.pods_secondary_cidr
  }

  secondary_ip_range {
    range_name    = var.services_secondary_range_name
    ip_cidr_range = var.services_secondary_cidr
  }
}

resource "google_compute_router" "nat_router" {
  count   = var.enable_nat ? 1 : 0
  project = var.host_project_id
  region  = var.region
  name    = "${var.vpc_name}-router"
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  count   = var.enable_nat ? 1 : 0
  project = var.host_project_id
  region  = var.region
  name    = "${var.vpc_name}-nat"
  router  = google_compute_router.nat_router[0].name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  host_project    = var.host_project_id
  service_project = var.service_project_id

  depends_on = [google_compute_shared_vpc_host_project.host]
}

resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "allow-ssh-iap"
  project = var.host_project_id
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

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

