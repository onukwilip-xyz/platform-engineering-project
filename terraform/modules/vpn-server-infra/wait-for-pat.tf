# resource "null_resource" "wait_for_pat" {
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command     = <<-EOT
#       echo "Polling for Netbird PAT in Secret Manager..."
#       for i in $(seq 1 40); do
#         if gcloud secrets versions access latest \
#             --secret="netbird-terraform-pat" \
#             --project="${var.service_project_id}" > /dev/null 2>&1; then
#           echo "PAT is available."
#           exit 0
#         fi
#         echo "Attempt $i/40 — waiting 30s..."
#         sleep 30
#       done
#       echo "Timed out waiting for PAT." && exit 1
#     EOT
#   }

#   depends_on = [ google_compute_instance.netbird_server ]
# }

# output "setup_key_ready" {
#   value = null_resource.wait_for_pat.id
# }