# ── Attacker Project ──────────────────────────────────────────────────────────
module "attacker_project" {
  source = "../../modules/projects"
  providers = {
    google = google.net
  }

  org_id             = var.org_id
  project_name       = var.attacker_project_name
  billing_account_id = var.billing_account_id
  labels             = merge(var.labels, { gcp-product = "resource-manager" })
}

# ── APIs ──────────────────────────────────────────────────────────────────────
module "attacker_apis" {
  source = "../../modules/enable_apis"
  providers = {
    google = google.net
  }

  project_id = module.attacker_project.project.project_id
  services = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "storage.googleapis.com",
    "iap.googleapis.com",
    # OS Login is enabled via the `enable-oslogin = "TRUE"` instance metadata
    # on master + workers. Without this API, IAP-tunneled SSH hangs trying
    # to auto-enable it (and the user's impersonated SA can't always do so).
    "oslogin.googleapis.com",
  ]

  depends_on = [module.attacker_project]
}

# ── In-project IAM for tf_platform_sa ─────────────────────────────────────────
module "attacker_platform_iam" {
  source = "../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.attacker_project.project.project_id
  bindings = [
    { role = "roles/compute.instanceAdmin.v1", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/compute.networkAdmin", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/compute.securityAdmin", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/iam.serviceAccountAdmin", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/iam.serviceAccountUser", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/storage.admin", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/serviceusage.serviceUsageAdmin", member = "serviceAccount:${var.tf_platform_sa_email}" },
  ]

  depends_on = [module.attacker_project]
}

# ── Default Compute SA logging role (mirrors envs/staging/project pattern) ────
module "attacker_compute_sa_logging_iam" {
  source = "../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.attacker_project.project.project_id
  bindings = [
    {
      role   = "roles/logging.logWriter"
      member = "serviceAccount:${module.attacker_project.project.number}-compute@developer.gserviceaccount.com"
    },
  ]

  depends_on = [module.attacker_apis]
}

# ── Shared VPC service-project attachment ─────────────────────────────────────
# Attaches the attacker project to the host project's Shared VPC. Done inline
# rather than via modules/service_networking because that module also binds
# GKE-specific service accounts (container-engine-robot, cloudservices) which
# don't exist in this project — container API isn't enabled here.
resource "google_compute_shared_vpc_service_project" "attacker" {
  provider        = google.net
  host_project    = local.shared_vpc_host_project_id
  service_project = module.attacker_project.project.project_id

  depends_on = [module.attacker_apis]
}

resource "google_compute_subnetwork_iam_member" "attacker_compute_sa_network_user" {
  provider   = google.net
  project    = local.shared_vpc_host_project_id
  region     = var.gke_subnet_region
  subnetwork = local.gke_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.attacker_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_compute_shared_vpc_service_project.attacker]
}

resource "google_compute_subnetwork_iam_member" "ddos_runner_network_user" {
  provider   = google.net
  project    = local.shared_vpc_host_project_id
  region     = var.gke_subnet_region
  subnetwork = local.gke_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.ddos_runner.email}"

  depends_on = [google_compute_shared_vpc_service_project.attacker]
}