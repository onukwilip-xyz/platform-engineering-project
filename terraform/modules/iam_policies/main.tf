resource "google_project_iam_member" "bindings" {
  for_each = { for i, binding in var.bindings : tostring(i) => binding }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}