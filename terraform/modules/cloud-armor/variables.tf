variable "project_id" {
  type        = string
  description = "Project ID where the security policy is created. Must be the same project that owns the backend services it will protect (i.e. the GKE service project)."
}

variable "policy_name" {
  type        = string
  description = "Name of the Cloud Armor security policy resource."
}

variable "description" {
  type        = string
  description = "Free-form description shown in the Cloud Armor console."
  default     = "Rate limiting + DDoS protection for the public Gateway"
}

variable "rate_limit_threshold_count" {
  type        = number
  description = "Number of requests per IP per interval that triggers throttling (HTTP 429). Above this and below ban_threshold_count the requester is throttled but not yet banned."
  default     = 300
}

variable "rate_limit_interval_sec" {
  type        = number
  description = "Sliding window (seconds) over which rate_limit_threshold_count and ban_threshold_count are measured."
  default     = 60
}

variable "ban_threshold_count" {
  type        = number
  description = "Number of requests per IP per interval that triggers a temporary ban (HTTP 429 for ban_duration_sec). Should be greater than rate_limit_threshold_count."
  default     = 550
}

variable "ban_duration_sec" {
  type        = number
  description = "How long (seconds) a banned IP is blocked before evaluation resumes."
  default     = 120
}

variable "log_level" {
  type        = string
  description = "Verbosity of Cloud Armor request logs. NORMAL logs only matched rules; VERBOSE logs full rule evaluation. Use VERBOSE during DDoS testing windows, NORMAL in steady state."
  default     = "VERBOSE"
}

variable "rate_limit_preview" {
  type        = bool
  description = "When true, the rate-limit/ban rule logs what it would block but does not actually block. Use for dry runs before a real DDoS test."
  default     = false
}

variable "enable_adaptive_protection" {
  type        = bool
  description = "Whether to enable Layer 7 adaptive protection (anomaly-based DDoS detection). Has no effect at low RPS but is free on Standard tier and useful as posture documentation."
  default     = true
}