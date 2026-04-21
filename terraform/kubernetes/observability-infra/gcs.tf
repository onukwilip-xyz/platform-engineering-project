resource "google_storage_bucket" "loki" {
  provider = google.platform

  name          = var.loki_bucket_name
  project       = var.service_project_id
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 10
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  labels = merge(var.labels, {
    component = "loki-chunks"
  })
}

resource "google_storage_bucket" "tempo" {
  provider = google.platform

  name          = var.tempo_bucket_name
  project       = var.service_project_id
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 10
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  labels = merge(var.labels, {
    component = "tempo-traces"
  })
}