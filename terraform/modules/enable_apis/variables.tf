variable "host_project" {
  type        = string
  description = "The ID of the host project where Shared VPC will be created."
}

variable "service_project" {
  type        = string
  description = "The ID of the service project where Compute resources will be created."
}

variable "extra_host_services" {
  type        = list(string)
  description = "Additional host services to enable."
  default = [ ]
}

variable "extra_service_services" {
  type        = list(string)
  description = "Additional service services to enable."
  default = [ ]
}