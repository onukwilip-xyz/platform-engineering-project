output "chart_ref" {
  description = "Full OCI reference for the pushed microservice chart (registry_url/chart_name:version)."
  value       = module.microservice_chart.chart_ref
}

output "chart_name" {
  description = "Name of the packaged microservice chart."
  value       = module.microservice_chart.chart_name
}

output "chart_version" {
  description = "Version of the packaged microservice chart."
  value       = module.microservice_chart.chart_version
}

output "registry_url" {
  description = "OCI registry URL the microservice chart was pushed to."
  value       = module.microservice_chart.registry_url
}