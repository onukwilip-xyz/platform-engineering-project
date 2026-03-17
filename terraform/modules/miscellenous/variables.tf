variable "service_project_id" {
  type        = string
  description = "Service project ID (where the Bucket and registry will be created)."
}

variable "region" {
  type        = string
  description = "Region for the Artifact Registry and backups bucket."
}

############################
# Artifact Registry
############################

variable "artifact_registry_repository_id" {
  type        = string
  description = "Artifact Registry repository ID (last segment of the repo name)."
}

variable "artifact_registry_location" {
  type        = string
  description = "Artifact Registry location (region like us-central1 or multi-region like us). Defaults to var.region when null."
  default     = null
}

variable "artifact_registry_format" {
  type        = string
  description = "Artifact Registry repository format (commonly DOCKER for container images and OCI-based Helm charts)."
  default     = "DOCKER"
}

variable "artifact_registry_description" {
  type        = string
  description = "Description for the Artifact Registry repository."
  default     = "Application artifacts (container images and Helm charts)."
}

variable "artifact_registry_docker_immutable_tags" {
  type        = bool
  description = "Whether to enable immutable tags for Docker repositories."
  default     = false
}

variable "artifact_registry_labels" {
  type        = map(string)
  description = "Labels to apply to the Artifact Registry repository."
  default     = {}
}

############################
# DB Backups Bucket
############################

variable "db_backups_bucket_name" {
  type        = string
  description = "Globally-unique GCS bucket name for database backups."
}

variable "db_backups_bucket_location" {
  type        = string
  description = "Bucket location (region/multi-region). Defaults to US when null."
  default     = null
}

variable "db_backups_bucket_storage_class" {
  type        = string
  description = "Storage class for the backups bucket (e.g., STANDARD, NEARLINE, COLDLINE, ARCHIVE)."
  default     = "STANDARD"
}

variable "db_backups_bucket_uniform_bucket_level_access" {
  type        = bool
  description = "Whether to enable uniform bucket-level access (recommended for IAM-only access control)."
  default     = true
}

variable "db_backups_bucket_public_access_prevention" {
  type        = string
  description = "Public access prevention setting for the bucket (recommended: enforced)."
  default     = "enforced"
}

variable "db_backups_bucket_versioning" {
  type        = bool
  description = "Whether to enable object versioning for the backups bucket."
  default     = true
}

variable "db_backups_bucket_force_destroy" {
  type        = bool
  description = "Whether to allow Terraform to delete the bucket even if it contains objects (use false for safety in prod)."
  default     = false
}

variable "db_backups_bucket_kms_key_name" {
  type        = string
  description = "Optional CMEK key name to encrypt bucket objects (full KMS key resource name). Set to null to use Google-managed encryption."
  default     = null
}

variable "db_backups_bucket_labels" {
  type        = map(string)
  description = "Labels to apply to the backups bucket."
  default     = {}
}

variable "db_backups_bucket_lifecycle_rules" {
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      num_newer_versions         = optional(number)
      with_state                 = optional(string)
      matches_storage_class      = optional(list(string))
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      days_since_noncurrent_time = optional(number)
    })
  }))

  description = "Optional lifecycle rules for the backups bucket (e.g., transition older objects to cheaper storage, prune older versions)."
  default     = []
}
