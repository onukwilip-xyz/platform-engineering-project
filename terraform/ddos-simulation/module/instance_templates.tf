resource "google_compute_instance_template" "mig" {
  for_each = local.mig_configs

  project     = module.attacker_project.project.project_id
  name_prefix = "ddos-${replace(each.key, "_", "-")}-"
  description = "Instance template for ${each.key} MIG (DDoS simulation worker)"

  machine_type   = var.worker_machine_type
  can_ip_forward = false
  region         = var.attack_region

  tags = [var.ssh_network_tag]

  labels = merge(local.vm_labels, { role = each.value.role_label_value })

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    network    = google_compute_network.attack.id
    subnetwork = google_compute_subnetwork.attack.self_link

    access_config {
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    enable-oslogin            = "TRUE"
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"

    locustfiles_bucket = google_storage_bucket.locustfiles.name
    locustfile         = each.value.locustfile
    master_nic0_ip     = google_compute_instance.master.network_interface[0].network_ip
    master_port        = each.value.master_port

    startup-script = templatefile("${path.module}/scripts/worker.sh.tftpl", {})
  }

  service_account {
    email  = google_service_account.ddos_runner.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_compute_shared_vpc_service_project.attacker,
    google_compute_subnetwork_iam_member.ddos_runner_network_user,
    google_storage_bucket_iam_member.ddos_runner_locustfiles_read,
    google_storage_bucket_object.locustfiles,
    google_compute_instance.master,
  ]
}