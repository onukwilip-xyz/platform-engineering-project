variable "service_project_id" {
  type        = string
  description = "Service project ID that owns the Artifact Registry helm repository."
}

variable "region" {
  type        = string
  description = "Artifact Registry location (region). Must match the helm repo's location."
}

variable "helm_repository_id" {
  type        = string
  description = "Artifact Registry repository ID for Helm charts. Sourced from the artifact-registry module output."
}

variable "chart_path" {
  type        = string
  description = "Absolute path to the microservice chart directory (the folder containing Chart.yaml). Terragrunt typically sets this via get_repo_root()."
}

variable "impersonate_sa_email" {
  type        = string
  description = "Service account email the local `gcloud auth print-access-token` impersonates to authenticate the `helm registry login` step."
}