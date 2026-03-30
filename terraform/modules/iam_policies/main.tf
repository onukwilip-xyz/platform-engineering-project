resource "google_project_iam_member" "bindings" {
  for_each = { for binding in var.bindings : "${binding.member}_${binding.role}" => binding }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}