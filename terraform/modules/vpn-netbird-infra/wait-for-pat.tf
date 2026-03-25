resource "null_resource" "wait_for_pat" {
  # provider = google.platform
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/wait_for_pat.sh"
    environment = {
      PAT_SECRET_ID = var.netbird_pat_secret_id
      PROJECT_ID    = var.service_project_id
    }
  }
}
