variable "org_id" {
  type        = string
  description = "GCP Organization ID."
}

variable "service_project_name" {
  type        = string
  description = "Name prefix for the service project (a random suffix is appended automatically)."
}

variable "billing_account_id" {
  type        = string
  description = "Billing account ID to associate with the service project."
}

variable "tf_network_sa_email" {
  type        = string
  description = "Service account email impersonated by the google.net provider."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Service account email impersonated by the google.platform provider."
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to all resources in this unit."
  default     = {}
}

variable "service_apis" {
  type        = list(string)
  description = "GCP APIs to enable on the service project."
  default = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "parametermanager.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iap.googleapis.com",
  ]
}