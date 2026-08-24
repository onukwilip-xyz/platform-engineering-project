# ── Project / billing / org ───────────────────────────────────────────────────

variable "org_id" {
  type        = string
  description = "GCP organization ID. Used when creating the attacker project."
}

variable "tf_platform_sa_email" {
  type        = string
  description = "Email of the platform Terraform service account. Granted in-project admin roles on the new attacker project so it can manage compute, IAM, GCS, and instance templates. Also granted compute.networkUser on the host's target subnet so it can allocate the master's static internal IP from there."
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
  description = "Labels applied to the attacker project, VMs, GCS bucket, and other taggable resources."
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
  description = "Prefix of the shared state in state_bucket (provides host_project_id, vpc_self_link, subnet_*, private_dns_zone)."
}

variable "gateway_state_prefix" {
  type        = string
  description = "Prefix of the gateway unit's state (provides public_gateway_global_ip)."
}

variable "subnet_region" {
  type        = string
  description = "Region of the target subnet. Required for the subnet IAM bindings and for allocating the master nic1 static internal IP. Must match the staging/production env's region."
}

variable "subnet_key" {
  type        = string
  description = "Key into the shared layer's subnet maps (subnet_names, subnet_self_links, ...) identifying the target environment's subnet."
}

# ── Target hostname (operator-chosen) ─────────────────────────────────────────

variable "target_public_host" {
  type        = string
  description = "Public FQDN that the attacker_hostname / baseline MIGs drive traffic against (e.g. users.public.example.com). Resolves via the public Cloud DNS zone to the GKE Gateway global IP. The attacker_ip MIG sends this as a Host header even when targeting the LB IP directly."
}

# ── Region & subnet for the attack VPC ────────────────────────────────────────

variable "attack_region" {
  type        = string
  description = "Region for the attacker project's standalone VPC, master VM, and all 3 MIGs. Single-region — per-IP isolation comes from each worker getting its own ephemeral public IP."
  default     = "us-central1"
}

variable "attack_zone" {
  type        = string
  description = "Zone within attack_region for the master VM (zonal resource)."
  default     = "us-central1-a"
}

variable "attack_subnet_cidr" {
  type        = string
  description = "Primary CIDR for the attack subnet."
  default     = "10.200.0.0/24"
}

# ── MIG sizes ─────────────────────────────────────────────────────────────────

variable "attacker_hostname_target_size" {
  type        = number
  description = "Number of VMs in the attacker_hostname MIG."
  default     = 2
}

variable "attacker_ip_target_size" {
  type        = number
  description = "Number of VMs in the attacker_ip MIG."
  default     = 1
}

variable "baseline_target_size" {
  type        = number
  description = "Number of VMs in the baseline MIG."
  default     = 1
}

# ── Locust master defaults (pre-fill the web UI; operator can override) ──────

variable "locust_users_attacker_hostname" {
  type        = number
  description = "Default number of simulated users for the attacker_hostname Locust master. Pre-fills the web UI 'Number of users' field; operator can override before clicking 'Start swarm'. Plan target: 10 users/VM × 2 VMs = 20."
  default     = 35
}

variable "locust_users_attacker_ip" {
  type        = number
  description = "Default number of simulated users for the attacker_ip Locust master. Same target as attacker_hostname."
  default     = 35
}

variable "locust_users_baseline" {
  type        = number
  description = "Default number of simulated users for the baseline Locust master. Plan target: 4 users/VM × 1 VM = 4."
  default     = 4
}

variable "locust_spawn_rate_attacker_hostname" {
  type        = number
  description = "Default user spawn rate (users/sec) for the attacker_hostname Locust master."
  default     = 35
}

variable "locust_spawn_rate_attacker_ip" {
  type        = number
  description = "Default user spawn rate (users/sec) for the attacker_ip Locust master."
  default     = 35
}

variable "locust_spawn_rate_baseline" {
  type        = number
  description = "Default user spawn rate (users/sec) for the baseline Locust master."
  default     = 4
}

variable "locust_run_time" {
  type        = string
  description = "Default test duration string passed to all 3 Locust masters. Operator can override on the web UI before clicking 'Start swarm'."
  default     = "30m"
}

# ── Master / worker shape ─────────────────────────────────────────────────────

variable "master_machine_type" {
  type        = string
  description = "GCE machine type for the master VM. e2-standard-2 = 2 vCPU, fits the quota math in DDOS-SIMULATION-WITH-LOCUST.md."
  default     = "e2-standard-2"
}

variable "worker_machine_type" {
  type        = string
  description = "GCE machine type for every MIG worker VM."
  default     = "e2-standard-2"
}

variable "ssh_network_tag" {
  type        = string
  description = "Network tag applied to all attacker-project VMs (master + workers). Matched by the IAP SSH firewall rule on the attack VPC."
  default     = "ddos-sim-ssh"
}

variable "master_network_tag" {
  type        = string
  description = "Network tag applied only to the master VM. Used by the workers→master firewall rule (dest tag) so only master can be reached on the Locust master ports 5557/5558/5559."
  default     = "ddos-master"
}

# ── Master nic1 static IP ─────────────────────────────────────────────────────

variable "master_nic1_static_ip_name" {
  type        = string
  description = "Name of the regional internal static address allocated for the master's nic1 in the host's GKE subnet. The ddos-plane DNS A record points here, so a stable name keeps the Locust UIs reachable across master rebuilds."
  default     = "ddos-master-nic1-ip"
}

# ── DNS ───────────────────────────────────────────────────────────────────────

variable "ddos_plane_dns_subdomain" {
  type        = string
  description = "Subdomain prefix under the private zone where the master's Locust UIs are reachable. Concatenated with private_domain (sourced from shared state) to form the final A record name — e.g. with default 'ddos-plane' and private_domain 'internal.example.com', the FQDN is ddos-plane.internal.example.com."
  default     = "ddos-plane"
}

variable "ddos_plane_dns_ttl" {
  type        = number
  description = "TTL (seconds) for the ddos-plane A record. Short so a master rebuild doesn't strand cached resolutions."
  default     = 60
}

# ── GCS bucket for locustfiles ────────────────────────────────────────────────

variable "locustfiles_bucket_name" {
  type        = string
  description = "Name of the GCS bucket holding the rendered locustfiles. Created in the attacker project. Bucket name must be globally unique — attacker project ID is appended automatically by the module if you leave it default."
  default     = ""
}

variable "locustfiles_bucket_location" {
  type        = string
  description = "Location for the locustfiles bucket. Regional matches attack_region; bucket isn't latency-sensitive, but staying in-region keeps egress free."
  default     = "US-CENTRAL1"
}
