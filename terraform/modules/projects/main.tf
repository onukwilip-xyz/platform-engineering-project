resource "google_organization_policy" "no_vpc_policy" {
  org_id     = var.org_id
  constraint = "compute.skipDefaultNetworkCreation"

  boolean_policy {
    enforced = true
  }
}

resource "google_project" "pe_host_project" {
  name       = var.host_project
  project_id = var.host_project
  org_id     = var.org_id
  billing_account = var.billing_account_id

  depends_on = [ google_organization_policy.no_vpc_policy ]
}

resource "google_project" "pe_service_project" {
  name       = var.service_project
  project_id = var.service_project
  org_id     = var.org_id
  billing_account = var.billing_account_id

    depends_on = [ google_organization_policy.no_vpc_policy ]
}