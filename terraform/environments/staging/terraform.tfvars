# ──────────────────────────────────────────────
# Provider / Auth
# ──────────────────────────────────────────────
tf_network_sa_email  = "tf-network@pe-terraform-project.iam.gserviceaccount.com"
tf_platform_sa_email = "tf-platform@pe-terraform-project.iam.gserviceaccount.com"
region               = "us-central1"
zone                 = "us-central1-a"

# ──────────────────────────────────────────────
# Remote State
# ──────────────────────────────────────────────
shared_state_bucket = "pe-tf-state-bucket"

# ──────────────────────────────────────────────
# Service Project
# ──────────────────────────────────────────────
org_id               = "256391743797"
service_project_name = "pe-staging-project"
billing_account_id   = "01E4F5-FFA2DF-D86AC5"

# ──────────────────────────────────────────────
# GKE
# ──────────────────────────────────────────────
gke_cluster_name            = "pe-staging-cluster"
gke_master_ipv4_cidr_block  = "172.16.0.16/28"
gke_node_service_account_id = "gke-staging-nodes"

gke_resource_labels = {
  env        = "staging"
  team       = "platform"
  managed_by = "terraform"
}

node_pools = [
  {
    name               = "large-node-pool"
    machine_type       = "e2-standard-4"
    initial_node_count = 0
    min_node_count     = 0
    max_node_count     = 3
    labels             = {}
    tags               = []
    resource_labels = {
      type = "large-node"
      team = "platform-engineering"
    }
    taints = [
      {
        key    = "workload-type"
        value  = "heavy"
        effect = "NO_EXECUTE"
      }
    ]
  },
  {
    name               = "small-node-pool"
    machine_type       = "e2-standard-2"
    initial_node_count = 0
    min_node_count     = 0
    max_node_count     = 3
    labels             = {}
    tags               = []
    resource_labels = {
      type = "small-node"
      team = "platform-engineering"
    }
  },
]

jump_service_account_id         = "staging-jump-vm-sa"
jump_vm_name                    = "staging-jump-vm"
jump_vm_access_sa_impersonators = ["user:onukwilip@onukwilip.xyz"]