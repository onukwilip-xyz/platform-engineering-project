resource "null_resource" "wait_for_pat" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "${path.module}/scripts/wait_for_pat.sh"
    environment = {
      PAT_SECRET_ID  = var.netbird_pat_secret_id
      PROJECT_ID     = var.project_id
      IMPERSONATE_SA = var.impersonate_sa_email
    }
  }
}