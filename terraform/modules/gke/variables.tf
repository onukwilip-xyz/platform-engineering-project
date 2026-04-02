variable "host_project_id" {
  type        = string
  description = "Host project ID (Shared VPC host project that owns the VPC/subnets)."
}

variable "service_project_id" {
  type        = string
  description = "Service project ID (where GKE, VMs, and other compute resources are created)."
}

variable "region" {
  type        = string
  description = "Region for the GKE cluster (should match the Shared VPC subnet region)."
}

variable "zone" {
  type        = string
  description = "Zone for the GKE cluster and related resources (should match the Shared VPC subnet zone)."
}

variable "service_project_number" {
  type        = string
  description = "Service project number (used for IAM bindings and Google-managed service accounts)."
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet for GKE worker nodes and the jump VM (typically the Shared VPC GKE subnet)."
}

# Shared VPC wiring (pass from networking module outputs)
variable "network_self_link" {
  type        = string
  description = "Self-link of the VPC network the cluster will use (typically the Shared VPC network in the host project)."
}

variable "subnet_self_link" {
  type        = string
  description = "Self-link of the subnet for GKE nodes and the jump VM (typically the Shared VPC subnet)."
}

variable "pods_secondary_range_name" {
  type        = string
  description = "Secondary range name in the subnet to allocate Pod IPs (VPC-native alias IPs)."
}

variable "services_secondary_range_name" {
  type        = string
  description = "Secondary range name in the subnet to allocate Service ClusterIP addresses."
}

# Cluster naming/config
variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster."
}

variable "release_channel" {
  type        = string
  description = "GKE release channel for the cluster (e.g., RAPID, REGULAR, STABLE)."
  default     = "REGULAR"
}

# Private cluster
variable "enable_private_endpoint" {
  type        = bool
  description = "Whether to enable a private control-plane endpoint (recommended for fully private access)."
  default     = true
}

variable "enable_private_nodes" {
  type        = bool
  description = "Whether to enable private nodes (recommended for fully private access)."
  default     = true
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "RFC1918 /28 CIDR range for the GKE control plane (must not overlap VPC/subnet/secondary ranges)."
}

variable "master_authorized_cidr" {
  type        = string
  description = "CIDR range allowed to access the Kubernetes API server endpoint (e.g., your GKE subnet CIDR)."
}

# Features
variable "enable_cluster_autoscaling" {
  type        = bool
  description = "Whether to enable cluster autoscaling at the cluster level."
  default     = true
}

variable "autoscaling_profile" {
  type        = string
  description = "Autoscaling profile for the cluster (e.g., OPTIMIZE_UTILIZATION or BALANCED)."
  default     = "OPTIMIZE_UTILIZATION"
}

variable "enable_vpa" {
  type        = bool
  description = "Whether to enable Vertical Pod Autoscaling (VPA) for the cluster."
  default     = true
}

variable "enable_managed_prometheus" {
  type        = bool
  description = "Whether to enable Managed Service for Prometheus (managed collection) for the cluster."
  default     = true
}

variable "enable_cost_management" {
  type        = bool
  description = "Whether to enable GKE cost management features (cost allocation/insights)."
  default     = true
}

variable "logging_components" {
  type        = list(string)
  description = "List of logging components to enable. Excluded WORKLOADS to avoid exporting container/workload logs (We'll use Loki for that)."
  default     = ["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER"]
}

variable "monitoring_components" {
  type        = list(string)
  description = "List of monitoring components to enable (commonly SYSTEM_COMPONENTS and WORKLOADS)."
  default     = ["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER", "STORAGE", "HPA", "POD", "DAEMONSET", "DEPLOYMENT", "STATEFULSET", "CADVISOR", "KUBELET", "DCGM", "JOBSET"]
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection on the GKE cluster (Change to true later, in production use)."
  default     = false
}

# Node Service Account
variable "node_service_account_id" {
  type        = string
  description = "Account ID (short name) for the user-managed GKE node service account to be created (no domain)."
}

variable "node_service_account_display_name" {
  type        = string
  description = "Display name for the user-managed GKE node service account."
  default     = "GKE node service account"
}

variable "node_service_account_extra_roles" {
  type        = list(string)
  description = "Optional extra project roles to grant the node service account (e.g., Artifact Registry read)."
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Common labels applied to all GKE resources (e.g., env, team, managed-by). The module merges these with purpose and gcp-product automatically."
  default     = {}
}

# Maintenance window
variable "maintenance_window_start_time" {
  type        = string
  description = "RFC3339 UTC start time for the recurring GKE maintenance window (e.g., '2025-01-04T22:00:00Z'). The window lasts 12 hours from this time."
  default     = "2025-01-04T22:00:00Z" # Saturday 22:00 UTC
}

variable "maintenance_window_recurrence" {
  type        = string
  description = "RFC5545 RRULE recurrence for the GKE maintenance window. Must satisfy GKE's constraint: >=48h of availability within any 32-day rolling window (e.g., weekly 12h = 4x12h = 48h/28d). Default is every Saturday night."
  default     = "FREQ=WEEKLY;BYDAY=SA"
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

    max_surge       = optional(number)
    max_unavailable = optional(number)

    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NO_SCHEDULE | PREFER_NO_SCHEDULE | NO_EXECUTE
    })), [])
  }))

  description = "List of node pool definitions. Each object defines a distinct node pool (name, machine type, initial size, autoscaling bounds, and optional labels/tags). Names must be unique."

  validation {
    condition     = length(var.node_pools) == length(toset([for np in var.node_pools : np.name]))
    error_message = "node_pools: each node pool 'name' must be unique."
  }

  validation {
    condition = alltrue([
      for np in var.node_pools : alltrue([
        for t in try(np.taints, []) :
        contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], t.effect)
      ])
    ])
    error_message = "node_pools.taints.effect must be one of: NO_SCHEDULE, PREFER_NO_SCHEDULE, NO_EXECUTE."
  }
}

variable "node_disk_type" {
  type        = string
  description = "Persistent disk type for node pool boot disks (pd-standard is HDD; pd-balanced is Balanced SSD; pd-ssd is Fast SSD)."
  default     = "pd-standard"
}

variable "node_disk_size_gb" {
  type        = number
  description = "Boot disk size (GB) for nodes in both node pools."
  default     = 70
}

variable "node_image_type" {
  type        = string
  description = "Node image type for the GKE nodes (e.g., COS_CONTAINERD, UBUNTU_CONTAINERD)."
  default     = "COS_CONTAINERD"
}

variable "node_oauth_scopes" {
  type        = list(string)
  description = "OAuth scopes for nodes (cloud-platform is broad; prefer IAM roles on the node service account for least privilege)."
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "common_node_labels" {
  type        = map(string)
  description = "Labels applied to all node pools (merged with per-pool labels)."
  default     = {}
}

variable "node_network_tags" {
  type        = list(string)
  description = "Network tags applied to GKE nodes (useful for firewall targeting)."
  default     = []
}

# Jump SA + Firewall Rule + VM
variable "jump_service_account_id" {
  type        = string
  description = "Account ID (short name) for the jump VM service account to be created (no domain). (This is temporal until VPN is created)"
}

variable "jump_service_account_display_name" {
  type        = string
  description = "Display name for the jump VM service account."
  default     = "Jump VM service account"
}

variable "jump_gke_role" {
  type        = string
  description = "IAM role to grant the jump VM service account for administering/accessing the GKE cluster. (This is temporal until VPN is created)"
  default     = "roles/container.clusterAdmin"
}

variable "jump_vm_access_service_account_id" {
  type        = string
  description = "Service account ID (short name) which will be used to connect to Jump VM via IAP, and connect to the GKE Cluster via SA impersonation"
  default = "jump-vm-access-sa"
}

variable "jump_vm_access_service_account_display_name" {
  type        = string
  description = "Display name for the jump VM access service account."
  default     = "Jump VM access service account"
}

variable "jump_vm_access_sa_impersonators" {
  type        = list(string)
  description = "List of additional principals (in addition to project editors/owners) allowed to impersonate the jump VM access service account for connecting to the jump VM and GKE cluster (e.g., user accounts or groups of human operators)."
  default     = []
}

variable "jump_vm_name" {
  type        = string
  description = "Name of the jump VM instance."
}

variable "jump_vm_machine_type" {
  type        = string
  description = "Machine type for the jump VM (used to access/administer the private cluster)."
  default     = "e2-medium"
}

variable "jump_vm_image" {
  type        = string
  description = "Boot image for the jump VM (full image path or family reference)."
  default     = "projects/debian-cloud/global/images/family/debian-12"
}

variable "jump_vm_boot_disk_size_gb" {
  type        = number
  description = "Boot disk size (GB) for the jump VM."
  default     = 20
}

variable "jump_vm_boot_disk_type" {
  type        = string
  description = "Boot disk type for the jump VM (pd-standard is HDD; pd-ssd is SSD)."
  default     = "pd-standard"
}

variable "jump_vm_network_tags" {
  type        = list(string)
  description = "Network tags applied to the jump VM (e.g., include 'ssh' to match an allow-ssh-iap firewall rule)."
  default     = ["ssh"]
}

variable "jump_vm_metadata" {
  type        = map(string)
  description = "Metadata key/value pairs for the jump VM (e.g., enable-oslogin, startup scripts, etc.)."
  default     = {}
}

variable "jump_vm_enable_oslogin" {
  type        = bool
  description = "Enable OS Login on the jump VM (recommended when humans access via an impersonated SA)."
  default     = true
}

variable "jump_vm_iap_firewall_name" {
  type        = string
  description = "Name of the firewall rule allowing IAP TCP forwarding to the jump VM(s)."
  default = "iap-ssh-access"
}

variable "jump_vm_iap_source_ranges" {
  type        = list(string)
  description = "Source ranges for IAP TCP forwarding. Default is the documented IAP range."
  default     = ["35.235.240.0/20"]
}

variable "jump_vm_iap_target_tags" {
  type        = list(string)
  description = "Network tags targeted by the IAP firewall rule (e.g., ['ssh'])."
  default     = ["ssh"]
}

variable "jump_vm_iap_tcp_ports" {
  type        = list(string)
  description = "TCP ports to allow from IAP to the targeted VMs (22 for SSH is the common case)."
  default     = ["22", "8888"]
}
