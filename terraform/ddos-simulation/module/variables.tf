# ── Project / billing / org ───────────────────────────────────────────────────

variable "org_id" {
  type        = string
  description = "GCP organization ID. Used when creating the attacker project."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Email of the platform Terraform service account. Granted in-project admin roles on the new attacker project so it can manage compute resources, instance templates, MIGs, IAM, and Secret Manager."
}

variable "billing_account_id" {
  type        = string
  description = "Billing account ID to attach the attacker project to."
}

variable "attacker_project_name" {
  type        = string
  description = "Name + prefix for the attacker project. A random suffix is appended by modules/projects."
  default     = "pe-ddos-sim"
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the attacker project, VMs, and other taggable resources."
  default = {
    purpose    = "ddos-simulation"
    managed-by = "terragrunt"
  }
}

# ── Remote-state lookups (target environment) ────────────────────────────────

variable "state_bucket" {
  type        = string
  description = "GCS bucket holding all Terraform state for the target environment."
}

variable "shared_state_prefix" {
  type        = string
  description = "Prefix of the shared state in state_bucket (provides host_project_id, vpc_self_link, gke_subnet_*)."
}

variable "gateway_state_prefix" {
  type        = string
  description = "Prefix of the gateway unit's state (provides public_gateway_global_ip, private_gateway_ip)."
}

variable "cert_manager_config_state_prefix" {
  type        = string
  description = "Prefix of the cert-manager-config unit's state (provides internal_ca_cert_pem)."
}

variable "gke_subnet_region" {
  type        = string
  description = "Region of the GKE subnet. Cannot be inferred from shared state outputs (only the self-link is exported), so the operator pins it here. Must match the staging/production env's region."
}

# ── Target hostname (operator-chosen) ─────────────────────────────────────────

variable "target_public_host" {
  type        = string
  description = "Public FQDN that the attacker_hostname MIG drives traffic against (e.g. users.public.example.com). Resolves via the public Cloud DNS zone to the GKE Gateway global IP. Operator-chosen because the subdomain isn't fixed by infra."
}

variable "private_gateway_metrics_host" {
  type        = string
  description = "FQDN that resolves to the private gateway IP via the private Cloud DNS zone (e.g. prometheus.internal.example.com). Used for the /etc/hosts override and as the Prometheus push URL host."
  default     = "prometheus.internal.pe.onukwilip.xyz"
}

# ── CA cert secret naming ─────────────────────────────────────────────────────

variable "internal_ca_secret_id" {
  type        = string
  description = "Name of the GSM secret in the attacker project that holds the CA cert."
  default     = "ddos-sim-internal-ca-cert"
}

# ── Regions & subnets for the attack VPC ──────────────────────────────────────

variable "attack_region" {
  type        = string
  description = "Region for the two attacker MIGs (attacker_hostname and attacker_ip)."
  default     = "us-central1"
}

variable "baseline_region" {
  type        = string
  description = "Region for the baseline MIG. Should differ from attack_region for distinct egress IP pools."
  default     = "europe-west1"
}

variable "attack_subnet_cidr" {
  type        = string
  description = "Primary CIDR for the attacker subnet (in attack_region)."
  default     = "10.200.0.0/24"
}

variable "baseline_subnet_cidr" {
  type        = string
  description = "Primary CIDR for the baseline subnet (in baseline_region)."
  default     = "10.201.0.0/24"
}

# ── Per-MIG load knobs (passed as instance metadata for the future load tool) ─

variable "attacker_hostname_target_size" {
  type        = number
  description = "Number of VMs in the attacker_hostname MIG."
  default     = 2
}

variable "attacker_ip_target_size" {
  type        = number
  description = "Number of VMs in the attacker_ip MIG."
  default     = 2
}

variable "baseline_target_size" {
  type        = number
  description = "Number of VMs in the baseline MIG."
  default     = 4
}

variable "attacker_write_rps" {
  type        = number
  description = "Per-VM write RPS for the two attacker MIGs (matches DDOS-IMPLEMENTATION.md)."
  default     = 7
}

variable "attacker_read_rps" {
  type        = number
  description = "Per-VM read RPS for the two attacker MIGs."
  default     = 3
}

variable "baseline_write_rps" {
  type        = number
  description = "Per-VM write RPS for the baseline MIG."
  default     = 2
}

variable "baseline_read_rps" {
  type        = number
  description = "Per-VM read RPS for the baseline MIG."
  default     = 1
}

variable "test_duration" {
  type        = string
  description = "Duration string passed to the load tool via metadata (e.g. 30m)."
  default     = "30m"
}

variable "machine_type" {
  type        = string
  description = "GCE machine type for every MIG VM."
  default     = "e2-standard-2"
}

variable "ssh_network_tag" {
  type        = string
  description = "Network tag applied to attacker VMs and matched by the IAP SSH firewall rule on the attack VPC."
  default     = "ddos-sim-ssh"
}

variable "metrics_egress_network_tag" {
  type        = string
  description = "Network tag applied to nic1 of attacker VMs and matched by the host VPC firewall rule that allows metrics egress to the private gateway."
  default     = "ddos-sim-metrics"
}
