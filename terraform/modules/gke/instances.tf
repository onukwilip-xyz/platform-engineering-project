# resource "google_compute_instance" "jump" {
#   provider = google.platform

#   project      = var.service_project_id
#   name         = var.jump_vm_name
#   zone         = var.zone
#   machine_type = var.jump_vm_machine_type
#   tags         = var.jump_vm_network_tags

#   boot_disk {
#     initialize_params {
#       image = var.jump_vm_image
#       size  = var.jump_vm_boot_disk_size_gb
#       type  = var.jump_vm_boot_disk_type
#     }
#   }

#   network_interface {
#     subnetwork = var.subnet_self_link
#   }

#   service_account {
#     email  = google_service_account.jump_sa.email
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   metadata = merge(
#     var.jump_vm_metadata,
#     {
#       enable-oslogin = var.jump_vm_enable_oslogin ? "TRUE" : "FALSE"
#       startup-script = file("${path.module}/scripts/tinyproxy_startup.sh")
#     }
#   )
# }