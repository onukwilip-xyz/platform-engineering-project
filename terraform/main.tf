module projects {
    source = "./modules/projects"
    providers = {
      google = google.net
    }

    org_id = var.org_id
    host_project = var.host_project
    service_project = var.service_project
    billing_account_id = var.billing_account_id
}

module iam_policies {
    source = "./modules/iam_policies"
    providers = {
      google = google.net
    }

    host_project = module.projects.host_project.project_id
    service_project = module.projects.service_project.project_id
    gke_subnet = var.gke_subnet
    tf_network_sa_email = var.tf_network_sa_email
    tf_platform_sa_email = var.tf_platform_sa_email
    region = var.region

    depends_on = [ module.projects ]
}

module "enable_apis" {
  source = "./modules/enable_apis"

  providers = {
    google.net      = google.net
    google.platform = google.platform
  }

  host_project =  module.projects.host_project.project_id
  service_project = module.projects.service_project.project_id

  depends_on = [ module.iam_policies ]
}
