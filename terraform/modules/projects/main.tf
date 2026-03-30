resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_project" "this" {
  name            = var.project_name
  project_id      = "${var.project_name}-${random_id.suffix.hex}"
  org_id          = var.org_id
  billing_account = var.billing_account_id
  deletion_policy = "DELETE"

  depends_on = [google_organization_policy.no_vpc_policy]
}