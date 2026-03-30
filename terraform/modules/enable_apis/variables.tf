variable "project_id" {
  type        = string
  description = "The GCP project ID to enable APIs on."
}

variable "services" {
  type        = list(string)
  description = "List of Google Cloud API services to enable."
}