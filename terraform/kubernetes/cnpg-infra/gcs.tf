resource "google_storage_bucket" "cnpg_backup" {
  provider = google.platform

  name          = var.backup_bucket_name
  project       = var.service_project_id
  location      = var.region
  force_destroy = false

  # Object Versioning — keeps previous versions of backup objects, enabling
  # recovery from accidental overwrites or deletes.
  versioning {
    enabled = true
  }

  # Hard-delete objects (and their non-current versions) after 37 days.
  # The 30-day retention policy in CNPG removes old backups from the manifest;
  # the extra 7 days gives Barman time to finish any in-flight deletions before
  # GCS sweeps the bucket.
  lifecycle_rule {
    condition {
      age = 37
    }
    action {
      type = "Delete"
    }
  }

  # Bucket-level IAM — individual object ACLs are disabled, permissions are
  # managed exclusively through IAM bindings (see iam.tf).
  uniform_bucket_level_access = true

  labels = merge(var.labels, {
    component = "cnpg-backup"
  })
}