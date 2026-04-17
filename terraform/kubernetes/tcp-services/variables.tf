variable "service_project_id" {
  type        = string
  description = "Service project ID where GKE runs. The shared VIP static IP must be reserved here."
}

variable "region" {
  type        = string
  description = "GCP region for the static IP (must match the GKE cluster region)."
}

variable "subnetwork" {
  type        = string
  description = "Self-link of the GKE subnet. The internal static IP is allocated from this subnet."
}