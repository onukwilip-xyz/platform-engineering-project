locals {
  artifact_registry_labels = merge(var.labels, {
    purpose     = "artifact-registry"
    gcp-product = "artifact-registry"
  })
  db_backups_labels = merge(var.labels, {
    purpose     = "db-backups"
    gcp-product = "cloud-storage"
  })
}

############################
# Artifact Registry (Docker/OCI) Repository
############################

resource "google_artifact_registry_repository" "app_repo" {
  project       = var.service_project_id
  location      = coalesce(var.artifact_registry_location, var.region)
  repository_id = var.artifact_registry_repository_id
  description   = var.artifact_registry_description
  format        = var.artifact_registry_format

  dynamic "docker_config" {
    for_each = var.artifact_registry_format == "DOCKER" ? [1] : []
    content {
      immutable_tags = var.artifact_registry_docker_immutable_tags
    }
  }

  labels = local.artifact_registry_labels
}

############################
# DB Backups Bucket
############################

resource "google_storage_bucket" "db_backups" {
  project                     = var.service_project_id
  name                        = var.db_backups_bucket_name
  location                    = coalesce(var.db_backups_bucket_location, "US")
  storage_class               = var.db_backups_bucket_storage_class
  uniform_bucket_level_access = var.db_backups_bucket_uniform_bucket_level_access
  public_access_prevention    = var.db_backups_bucket_public_access_prevention
  force_destroy               = var.db_backups_bucket_force_destroy
  labels                      = local.db_backups_labels

  versioning {
    enabled = var.db_backups_bucket_versioning
  }

  dynamic "encryption" {
    for_each = var.db_backups_bucket_kms_key_name == null ? [] : [1]
    content {
      default_kms_key_name = var.db_backups_bucket_kms_key_name
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.db_backups_bucket_lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }

      condition {
        age                        = try(lifecycle_rule.value.condition.age, null)
        num_newer_versions         = try(lifecycle_rule.value.condition.num_newer_versions, null)
        with_state                 = try(lifecycle_rule.value.condition.with_state, null)
        matches_storage_class      = try(lifecycle_rule.value.condition.matches_storage_class, null)
        matches_prefix             = try(lifecycle_rule.value.condition.matches_prefix, null)
        matches_suffix             = try(lifecycle_rule.value.condition.matches_suffix, null)
        days_since_noncurrent_time = try(lifecycle_rule.value.condition.days_since_noncurrent_time, null)
      }
    }
  }
}
