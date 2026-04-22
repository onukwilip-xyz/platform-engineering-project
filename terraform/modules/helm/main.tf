locals {
  chart         = yamldecode(file("${var.chart_path}/Chart.yaml"))
  chart_name    = local.chart.name
  chart_version = local.chart.version
  package_name  = "${local.chart_name}-${local.chart_version}.tgz"
  registry_url  = "oci://${var.registry_location}-docker.pkg.dev/${var.service_project_id}/${var.repository_id}"

  # Hash of all chart files — triggers re-run only when chart content changes.
  chart_hash = sha1(join("", [
    for f in sort(fileset(var.chart_path, "**")) : filesha1("${var.chart_path}/${f}")
  ]))
}

resource "null_resource" "helm_push" {
  triggers = {
    chart_hash = local.chart_hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Packaging Helm chart '${local.chart_name}' v${local.chart_version}..."
      helm package "${var.chart_path}" --destination "/tmp"

      echo "Authenticating with Artifact Registry..."
      gcloud auth print-access-token --impersonate-service-account="${var.impersonate_sa_email}" | helm registry login \
        "${var.registry_location}-docker.pkg.dev" \
        --username oauth2accesstoken \
        --password-stdin

      echo "Pushing ${local.package_name} to ${local.registry_url}..."
      helm push "/tmp/${local.package_name}" "${local.registry_url}"

      echo "Done."
    EOT
  }
}