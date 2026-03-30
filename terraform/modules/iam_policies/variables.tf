variable "project_id" {
  type        = string
  description = "The GCP project ID to apply IAM bindings to."
}

variable "bindings" {
  type = list(object({
    role   = string
    member = string
  }))
  description = "List of IAM bindings to apply. Each binding specifies a role and a member."
}