variable "service_project_id" {
  type        = string
  description = "Service project ID (where the Bucket and registry will be created)."
}

variable "region" {
  type        = string
  description = "Region for the Artifact Registry and backups bucket."
}

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

variable "labels" {
  type        = map(string)
  description = "Common labels applied to all resources (e.g., env, team, managed-by). The module merges these with purpose and gcp-product automatically."
  default     = {}
}