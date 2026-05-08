resource "google_compute_region_instance_group_manager" "mig" {
  for_each = local.mig_configs

  project            = module.attacker_project.project.project_id
  name               = "ddos-${replace(each.key, "_", "-")}-mig"
  region             = each.value.region
  base_instance_name = "ddos-${replace(each.key, "_", "-")}"
  target_size        = each.value.target_size

  version {
    instance_template = google_compute_instance_template.mig[each.key].self_link
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 3
    max_unavailable_fixed = 0
    replacement_method    = "SUBSTITUTE"
  }

  lifecycle {
    create_before_destroy = true
  }
}