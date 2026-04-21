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

# ── Loki GCS bucket ───────────────────────────────────────────────────────────

variable "loki_bucket_name" {
  type        = string
  description = "Name of the GCS bucket Loki writes chunks, index, and rulers to."
  default     = "pe-loki-chunks"
}

# ── Loki GCP service account (Workload Identity) ─────────────────────────────

variable "loki_gcp_sa_id" {
  type        = string
  description = "Account ID of the GCP service account Loki pods impersonate via WIF for GCS access."
  default     = "loki-gcs"
}

# ── Kubernetes coordinates ────────────────────────────────────────────────────

variable "logging_namespace" {
  type        = string
  description = "Kubernetes namespace where Loki (and Alloy) run. Used to build the WIF member string."
  default     = "logging"
}

variable "loki_ksa_name" {
  type        = string
  description = "Name of the Kubernetes ServiceAccount the Loki Helm chart creates. Must match the chart's `serviceAccount.name` value so the WIF binding lines up."
  default     = "loki"
}

# ── Tempo GCS bucket ──────────────────────────────────────────────────────────

variable "tempo_bucket_name" {
  type        = string
  description = "Name of the GCS bucket Tempo writes trace blocks to."
  default     = "pe-tempo-traces"
}

# ── Tempo GCP service account (Workload Identity) ────────────────────────────

variable "tempo_gcp_sa_id" {
  type        = string
  description = "Account ID of the GCP service account Tempo pods impersonate via WIF for GCS access."
  default     = "tempo-gcs"
}

# ── Tempo Kubernetes coordinates ──────────────────────────────────────────────

variable "tracing_namespace" {
  type        = string
  description = "Kubernetes namespace where Tempo runs. Used to build the WIF member string."
  default     = "tracing"
}

variable "tempo_ksa_name" {
  type        = string
  description = "Name of the Kubernetes ServiceAccount the Tempo Helm chart creates. Must match the chart's `serviceAccount.name` value so the WIF binding lines up."
  default     = "tempo"
}