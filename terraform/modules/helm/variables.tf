variable "service_project_id" {
  type        = string
  description = "GCP project ID where the Artifact Registry repository lives."
}

variable "registry_location" {
  type        = string
  description = "Artifact Registry location (e.g. us-central1). Must match the repository's location."
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository ID to push the Helm chart to."
}

variable "chart_path" {
  type        = string
  description = "Absolute or root-relative path to the Helm chart directory (the folder containing Chart.yaml)."
}

variable "impersonate_sa_email" {
  type        = string
  description = "Service account email to impersonate for script-based operations (Secret Manager, Parameter Manager access)."
}