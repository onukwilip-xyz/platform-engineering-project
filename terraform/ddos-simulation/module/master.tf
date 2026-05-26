resource "google_compute_address" "master_nic1" {
  project      = module.attacker_project.project.project_id
  name         = var.master_nic1_static_ip_name
  region       = var.gke_subnet_region
  address_type = "INTERNAL"
  subnetwork   = local.gke_subnet_self_link

  depends_on = [
    google_compute_shared_vpc_service_project.attacker,
    google_compute_subnetwork_iam_member.attacker_compute_sa_network_user,
  ]
}

# ── Master VM ─────────────────────────────────────────────────────────────────
resource "google_compute_instance" "master" {
  project      = module.attacker_project.project.project_id
  name         = "ddos-master"
  machine_type = var.master_machine_type
  zone         = var.attack_zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
    auto_delete = true
  }

  # nic0: standalone attack VPC. Workers (in the same VPC) connect to the master VM
  network_interface {
    network    = google_compute_network.attack.id
    subnetwork = google_compute_subnetwork.attack.self_link
  }

  # nic1: Shared VPC GKE subnet. Enables connections from the VPN
  network_interface {
    network    = local.shared_vpc_self_link
    subnetwork = local.gke_subnet_self_link
    network_ip = google_compute_address.master_nic1.address
  }

  metadata = {
    enable-oslogin            = "TRUE"
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"

    locustfiles_bucket = google_storage_bucket.locustfiles.name

    locust_users_attacker_hostname      = tostring(var.locust_users_attacker_hostname)
    locust_users_attacker_ip            = tostring(var.locust_users_attacker_ip)
    locust_users_baseline               = tostring(var.locust_users_baseline)
    locust_spawn_rate_attacker_hostname = tostring(var.locust_spawn_rate_attacker_hostname)
    locust_spawn_rate_attacker_ip       = tostring(var.locust_spawn_rate_attacker_ip)
    locust_spawn_rate_baseline          = tostring(var.locust_spawn_rate_baseline)
    locust_run_time                     = var.locust_run_time

    startup-script = templatefile("${path.module}/scripts/master.sh.tftpl", {})
  }

  tags = [var.ssh_network_tag, var.master_network_tag]

  labels = merge(var.labels, {
    role        = "ddos-master"
    gcp-product = "compute"
  })

  service_account {
    email  = google_service_account.ddos_runner.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_shared_vpc_service_project.attacker,
    google_compute_subnetwork_iam_member.ddos_runner_network_user,
    google_storage_bucket_iam_member.ddos_runner_locustfiles_read,
    google_storage_bucket_object.locustfiles,
  ]
}