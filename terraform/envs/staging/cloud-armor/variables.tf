variable "service_project_id" {
  type        = string
  description = "Service project where the security policy is created. Must own the backend services protected by it."
}

variable "policy_name" {
  type        = string
  description = "Name for the public Gateway's Cloud Armor security policy."
  default     = "public-gateway-armor"
}

variable "rate_limit_threshold_count" {
  type        = number
  description = "Throttle threshold (HTTP 429) per IP within rate_limit_interval_sec."
  default     = 300
}

variable "ban_threshold_count" {
  type        = number
  description = "Ban threshold per IP within rate_limit_interval_sec."
  default     = 550
}

variable "rate_limit_interval_sec" {
  type        = number
  description = "Sliding window for rate-limit/ban counters."
  default     = 60
}

variable "ban_duration_sec" {
  type        = number
  description = "How long banned IPs stay blocked."
  default     = 120
}

variable "log_level" {
  type        = string
  description = "Cloud Armor log verbosity (NORMAL or VERBOSE)."
  default     = "VERBOSE"
}

variable "rate_limit_preview" {
  type        = bool
  description = "Run the rate-limit rule in preview mode (logs without blocking)."
  default     = false
}

variable "enable_adaptive_protection" {
  type        = bool
  description = "Enable Layer 7 adaptive protection."
  default     = true
}