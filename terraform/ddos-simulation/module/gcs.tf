locals {
  # Default to a deterministic name keyed on the attacker project ID so the
  # bucket is globally unique without operator intervention. Override via
  # var.locustfiles_bucket_name when needed.
  effective_locustfiles_bucket_name = (
    var.locustfiles_bucket_name != ""
    ? var.locustfiles_bucket_name
    : "${module.attacker_project.project.project_id}-locustfiles"
  )

  # Map of object name → rendered locustfile content. Keys are the filenames
  # that appear in the bucket and that worker.sh.tftpl fetches by metadata.
  locustfile_objects = {
    "locustfile_attacker_hostname.py" = templatefile(
      "${path.module}/locust/locustfile_attacker_hostname.py.tftpl",
      {
        target_public_host = var.target_public_host
      },
    )
    "locustfile_attacker_ip.py" = templatefile(
      "${path.module}/locust/locustfile_attacker_ip.py.tftpl",
      {
        target_public_ip   = local.target_public_ip
        target_public_host = var.target_public_host
      },
    )
    "locustfile_baseline.py" = templatefile(
      "${path.module}/locust/locustfile_baseline.py.tftpl",
      {
        target_public_host = var.target_public_host
      },
    )
  }
}

resource "google_storage_bucket" "locustfiles" {
  project       = module.attacker_project.project.project_id
  name          = local.effective_locustfiles_bucket_name
  location      = var.locustfiles_bucket_location
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = false
  }

  labels = var.labels

  depends_on = [
    module.attacker_apis,
    module.attacker_platform_iam,
  ]
}

resource "google_storage_bucket_object" "locustfiles" {
  for_each = local.locustfile_objects

  bucket  = google_storage_bucket.locustfiles.name
  name    = each.key
  content = each.value

  # Render hash so operators see content drift in plans even though the
  # filename stays stable across edits.
  content_type = "text/x-python"
}
