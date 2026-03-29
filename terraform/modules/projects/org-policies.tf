resource "google_organization_policy" "no_vpc_policy" {
  org_id     = var.org_id
  constraint = "compute.skipDefaultNetworkCreation"

  boolean_policy {
    enforced = true
  }
}