# ──────────────────────────────────────────────
# Provider / Auth
# ──────────────────────────────────────────────

# Required by the kubernetes and helm providers, which cannot reference module
# outputs in their configuration blocks — only variables and data sources.
# Populate from the GKE layer outputs before applying this layer:
#   export TF_VAR_cluster_endpoint=$(terraform output -raw gke_cluster_endpoint)
#   export TF_VAR_cluster_ca_certificate=$(terraform output -raw gke_cluster_ca_certificate)
variable "cluster_endpoint" {
  type        = string
  description = "GKE cluster API endpoint (raw IP, no https:// scheme). Fed into the kubernetes and helm provider configurations."
  sensitive   = true
  default     = "" # safe default so the staging layer can be planned/applied before GKE exists
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Base64-encoded cluster CA certificate from GKE master_auth. Fed into the kubernetes and helm provider configurations."
  sensitive   = true
  default     = "" # safe default so the staging layer can be planned/applied before GKE exists
}
variable "tf_network_sa_email" {
  type        = string
  description = "Service account email to impersonate for the tf-network provider (host project operations)."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Service account email to impersonate for the tf-platform provider (service project operations)."
}

variable "region" {
  type        = string
  description = "Default region for Google provider operations."
}

variable "zone" {
  type        = string
  description = "Default zone for Google provider operations."
}

# ──────────────────────────────────────────────
# Remote State (shared layer)
# ──────────────────────────────────────────────
variable "shared_state_bucket" {
  type        = string
  description = "GCS bucket name where the shared layer state is stored."
}

# ──────────────────────────────────────────────
# Service Project
# ──────────────────────────────────────────────
variable "org_id" {
  type        = string
  description = "Organization ID for the Google Cloud organization."
}

variable "service_project_name" {
  type        = string
  description = "Name and ID prefix for the service project."
}

variable "billing_account_id" {
  type        = string
  description = "The ID of the billing account associated with the project."
}

# ──────────────────────────────────────────────
# GKE
# ──────────────────────────────────────────────
variable "gke_cluster_name" {
  type        = string
  description = "Name of the GKE cluster."
}

variable "gke_master_ipv4_cidr_block" {
  type        = string
  description = "The /28 CIDR block for the GKE master (must not overlap with VPC/subnet/secondary ranges)."
}

variable "gke_node_service_account_id" {
  type        = string
  description = "The ID of the service account to be used by GKE nodes."
}

variable "labels" {
  type        = map(string)
  description = "Common labels to apply to all resources in this environment (e.g., env, team, managed-by)."
  default     = {}
}

variable "node_pools" {
  type = list(object({
    name               = string
    machine_type       = string
    initial_node_count = number
    min_node_count     = number
    max_node_count     = number

    labels          = optional(map(string), {})
    resource_labels = optional(map(string), {})
    tags            = optional(list(string), [])

    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  description = "List of node pool definitions for the GKE cluster."
}

variable "jump_service_account_id" {
  type        = string
  description = "Account ID for the jump VM service account."
  default     = "jump-vm-sa"
}

variable "jump_vm_name" {
  type        = string
  description = "Name of the jump VM instance."
  default     = "jump-vm"
}

variable "jump_vm_access_sa_impersonators" {
  type        = list(string)
  description = "Principals allowed to impersonate the jump VM access service account."
  default     = []
}

# ──────────────────────────────────────────────
# Artifact Registry
# ──────────────────────────────────────────────
variable "artifact_repositories" {
  type = map(object({
    repository_id  = string
    description    = string
    format         = string
    immutable_tags = bool
    labels         = map(string)
  }))
  description = "Map of Artifact Registry repositories to create. Keys are logical names (e.g. 'images', 'charts')."
}
