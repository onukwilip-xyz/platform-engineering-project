# ──────────────────────────────────────────────
# Read shared layer outputs
# ──────────────────────────────────────────────
data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = var.shared_state_bucket
    prefix = "shared/"
  }
}

locals {
  shared = data.terraform_remote_state.shared.outputs
}

# ──────────────────────────────────────────────
# Service Project
# ──────────────────────────────────────────────
module "service_project" {
  source = "../../modules/projects"
  providers = {
    google = google.net
  }

  org_id             = var.org_id
  project_name       = var.service_project_name
  billing_account_id = var.billing_account_id
  labels             = merge(var.labels, { purpose = "service-project" })
}

# ──────────────────────────────────────────────
# Service Project IAM
# ──────────────────────────────────────────────
module "service_iam" {
  source = "../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.service_project.project.project_id
  bindings = [
    {
      role   = "roles/container.admin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role = "roles/compute.instanceAdmin.v1",
    member = "serviceAccount:${var.tf_platform_sa_email}" }
    ,
    {
      role   = "roles/iam.serviceAccountAdmin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role   = "roles/iam.serviceAccountUser",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role   = "roles/artifactregistry.admin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role   = "roles/storage.admin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role   = "roles/serviceusage.serviceUsageAdmin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role   = "roles/secretmanager.admin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
    {
      role   = "roles/parametermanager.admin",
      member = "serviceAccount:${var.tf_platform_sa_email}"
    },
  ]

  depends_on = [module.service_project]
}

# ──────────────────────────────────────────────
# Service Project APIs
# ──────────────────────────────────────────────
module "service_apis" {
  source = "../../modules/enable_apis"
  providers = {
    google = google.platform
  }

  project_id = module.service_project.project.project_id
  services = [
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

  depends_on = [module.service_iam]
}

# ──────────────────────────────────────────────
# Post-APIs IAM (requires default compute SA to exist)
# ──────────────────────────────────────────────
module "service_compute_engine_sa_logging_iam" {
  source = "../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.service_project.project.project_id
  bindings = [
    {
      role   = "roles/logging.logWriter"
      member = "serviceAccount:${module.service_project.project.number}-compute@developer.gserviceaccount.com"
    },
  ]

  depends_on = [module.service_apis]
}

# ──────────────────────────────────────────────
# Service Networking (attach to Shared VPC + subnet IAM)
# ──────────────────────────────────────────────
module "service_networking" {
  source = "../../modules/service_networking"
  providers = {
    google = google.net
  }

  host_project_id        = local.shared.host_project_id
  service_project_id     = module.service_project.project.project_id
  service_project_number = module.service_project.project.number
  region                 = var.region
  subnet_name            = local.shared.gke_subnet_name
  tf_platform_sa_email   = var.tf_platform_sa_email

  depends_on = [module.service_apis]
}

# ──────────────────────────────────────────────
# GKE Cluster
# ──────────────────────────────────────────────
module "gke" {
  source = "../../modules/gke"
  providers = {
    google.net      = google.net
    google.platform = google.platform
  }

  host_project_id        = local.shared.host_project_id
  service_project_id     = module.service_project.project.project_id
  service_project_number = module.service_project.project.number
  region                 = var.region
  zone                   = var.zone

  network_self_link             = local.shared.vpc_self_link
  subnet_self_link              = local.shared.gke_subnet_self_link
  pods_secondary_range_name     = local.shared.pods_secondary_range_name
  services_secondary_range_name = local.shared.services_secondary_range_name
  subnet_name                   = local.shared.gke_subnet_name

  cluster_name           = var.gke_cluster_name
  master_authorized_cidr = local.shared.gke_subnet_cidr
  master_ipv4_cidr_block = var.gke_master_ipv4_cidr_block
  labels                 = var.labels

  node_service_account_id = var.gke_node_service_account_id
  node_pools              = var.node_pools

  jump_service_account_id         = var.jump_service_account_id
  jump_vm_name                    = var.jump_vm_name
  jump_vm_access_sa_impersonators = var.jump_vm_access_sa_impersonators

  depends_on = [module.service_networking]
}

# ──────────────────────────────────────────────
# Artifact Registry
# ──────────────────────────────────────────────

module "artifact_registry" {
  source = "../../modules/artifact_registry"
  providers = {
    google = google.platform
  }

  service_project_id = module.service_project.project.project_id
  region             = var.region
  repositories       = var.artifact_repositories
  labels             = var.labels

  depends_on = [module.service_apis]
}