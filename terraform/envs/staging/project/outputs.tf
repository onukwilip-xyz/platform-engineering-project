output "service_project_id" {
  description = "ID of the created service project. Consumed by networking, gke, and artifact-registry units."
  value       = module.service_project.project.project_id
}

output "service_project_number" {
  description = "Number of the created service project. Consumed by the networking unit for Shared VPC IAM bindings."
  value       = module.service_project.project.number
}