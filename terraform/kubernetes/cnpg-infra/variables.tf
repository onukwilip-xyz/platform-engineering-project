# ── Labels ───────────────────────────────────────────────────────────────────

variable "labels" {
  type        = map(string)
  description = "Labels applied to GCP resources. Passed from the env-level terragrunt config so values stay environment-specific."
  default     = {}
}

# ── Project ───────────────────────────────────────────────────────────────────

variable "service_project_id" {
  type        = string
  description = "GCP project ID where the GKE cluster and GCS bucket live."
}

variable "region" {
  type        = string
  description = "GCS bucket location (region)."
  default     = "us-central1"
}

# ── GCS backup bucket ─────────────────────────────────────────────────────────

variable "backup_bucket_name" {
  type        = string
  description = "Name of the GCS bucket Barman Cloud writes PostgreSQL backups to."
  default     = "pe-cnpg-postgres-backups"
}

# ── GCP service account (Workload Identity) ───────────────────────────────────

variable "backup_gcp_sa_id" {
  type        = string
  description = "Account ID of the GCP service account CNPG pods impersonate via WIF for GCS access."
  default     = "cnpg-backup"
}

# ── Kubernetes coordinates ────────────────────────────────────────────────────

variable "postgres_namespace" {
  type        = string
  description = "Kubernetes namespace where the CNPG Cluster runs. Used to build the WIF member string."
  default     = "postgres"
}

variable "cnpg_cluster_name" {
  type        = string
  description = "Name of the CNPG Cluster CR. The operator creates a KSA with this name, which is the WIF subject."
  default     = "postgres-cluster"
}