variable "service_project_id" {
  type        = string
  description = "Service project ID where the Artifact Registry repositories will be created."
}

variable "region" {
  type        = string
  description = "Default region for the repositories. Used when location is not set."
}

variable "location" {
  type        = string
  description = "Artifact Registry location (region like us-central1 or multi-region like us). Defaults to var.region when null."
  default     = null
}

variable "repositories" {
  type = map(object({
    repository_id  = string
    description    = string
    format         = string
    immutable_tags = bool
    labels         = map(string)
  }))
  description = "Map of Artifact Registry repositories to create. Keys are logical names (e.g. 'images', 'charts')."
}

variable "labels" {
  type        = map(string)
  description = "Common labels applied to all resources (e.g., env, team, managed-by). The module merges these with purpose and gcp-product automatically."
  default     = {}
}