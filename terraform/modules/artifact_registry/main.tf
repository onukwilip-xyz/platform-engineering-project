locals {
  artifact_registry_labels = merge(var.labels, {
    purpose     = "artifact-registry"
    gcp-product = "artifact-registry"
  })
}

resource "google_artifact_registry_repository" "repos" {
  for_each = var.repositories

  project       = var.service_project_id
  location      = coalesce(var.location, var.region)
  repository_id = each.value.repository_id
  description   = each.value.description
  format        = each.value.format

  dynamic "docker_config" {
    for_each = each.value.format == "DOCKER" ? [1] : []
    content {
      immutable_tags = each.value.immutable_tags
    }
  }

  labels = merge(local.artifact_registry_labels, each.value.labels)
}
