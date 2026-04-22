output "chart_name" {
  description = "Name of the packaged Helm chart."
  value       = local.chart_name
}

output "chart_version" {
  description = "Version of the packaged Helm chart."
  value       = local.chart_version
}

output "registry_url" {
  description = "OCI registry URL the chart was pushed to."
  value       = local.registry_url
}

output "chart_ref" {
  description = "Full OCI reference for the pushed chart (registry_url/chart_name:version)."
  value       = "${local.registry_url}/${local.chart_name}:${local.chart_version}"
}