resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_project" "pe_host_project" {
  name       = var.host_project
  project_id = "${var.host_project}-${random_id.suffix.hex}"
  org_id     = var.org_id
  billing_account = var.billing_account_id
  deletion_policy = "DELETE"

  depends_on = [ google_organization_policy.no_vpc_policy ]
}

resource "google_project" "pe_service_project" {
  name       = var.service_project
  project_id = "${var.service_project}-${random_id.suffix.hex}"
  org_id     = var.org_id
  billing_account = var.billing_account_id
  deletion_policy = "DELETE"

  depends_on = [ google_organization_policy.no_vpc_policy ]
}