variable "argocd_namespace" {
  type        = string
  description = "Namespace where ArgoCD is installed. The App-of-Apps Application is created here."
  default     = "argocd"
}

variable "repo_url" {
  type        = string
  description = "Git repository URL ArgoCD tracks for the app-of-apps manifests path."
}

variable "target_revision" {
  type        = string
  description = "Git branch, tag, or commit SHA ArgoCD should track. Typically sourced from the CD pipeline's branch context (e.g. TF_VAR_target_revision=staging)."
  default     = "HEAD"
}

variable "backup_gcp_sa_email" {
  type        = string
  description = "Email of the GCP SA for CNPG backup via Workload Identity."
}

variable "backup_bucket_name" {
  type        = string
  description = "GCS bucket name for CNPG Barman backups."
}

variable "shared_vip_address" {
  type        = string
  description = "IP address of the tcp-services shared VIP for the pooler LoadBalancer."
}

variable "cluster_issuer_name" {
  type        = string
  description = "cert-manager ClusterIssuer name for PostgreSQL TLS certificates."
  default     = "internal-ca"
}

variable "cnpg_operator_chart_version" {
  type        = string
  description = "Pinned version of the cloudnative-pg Helm chart. Bump via PR to roll the operator forward."
  default     = "0.23.0"
}