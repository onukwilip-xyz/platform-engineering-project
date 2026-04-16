# ── Service Project ───────────────────────────────────────────────────────────
module "service_project" {
  source = "../../../modules/projects"
  providers = {
    google = google.net
  }

  org_id             = var.org_id
  project_name       = var.service_project_name
  billing_account_id = var.billing_account_id
  labels             = merge(var.labels, { purpose = "service-project" })
}

# ── Service Project IAM ───────────────────────────────────────────────────────
module "service_iam" {
  source = "../../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.service_project.project.project_id
  bindings = [
    { role = "roles/container.admin",                member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/compute.instanceAdmin.v1",       member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/compute.loadBalancerAdmin",      member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/iam.serviceAccountAdmin",        member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/iam.serviceAccountUser",         member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/artifactregistry.admin",         member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/storage.admin",                  member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/serviceusage.serviceUsageAdmin", member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/secretmanager.admin",            member = "serviceAccount:${var.tf_platform_sa_email}" },
    { role = "roles/parametermanager.admin",         member = "serviceAccount:${var.tf_platform_sa_email}" },
  ]

  depends_on = [module.service_project]
}

# ── Service Project APIs ──────────────────────────────────────────────────────
module "service_apis" {
  source = "../../../modules/enable_apis"
  providers = {
    google = google.platform
  }

  project_id = module.service_project.project.project_id
  services   = var.service_apis

  depends_on = [module.service_iam]
}

# ── Post-API IAM (default Compute SA needs logging role after APIs enable) ────
module "compute_sa_logging_iam" {
  source = "../../../modules/iam_policies"
  providers = {
    google = google.net
  }

  project_id = module.service_project.project.project_id
  bindings = [{
    role   = "roles/logging.logWriter"
    member = "serviceAccount:${module.service_project.project.number}-compute@developer.gserviceaccount.com"
  }]

  depends_on = [module.service_apis]
}