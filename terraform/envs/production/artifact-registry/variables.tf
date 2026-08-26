variable "service_project_id" {
  type        = string
  description = "Service project ID."
}

variable "region" {
  type        = string
  description = "GCP region for the Artifact Registry repositories."
}

variable "repositories" {
  type = map(object({
    repository_id  = string
    description    = string
    format         = string
    immutable_tags = bool
    labels         = map(string)
  }))
  description = "Map of Artifact Registry repositories to create."
}

variable "labels" {
  type    = map(string)
  default = {}
}