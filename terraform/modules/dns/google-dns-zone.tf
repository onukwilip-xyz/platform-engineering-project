# Public DNS Zone for the subdomain, accessible from the internet
resource "google_dns_managed_zone" "public_zone" {
  name        = replace("${var.subdomain}-${var.root_domain}", ".", "-") # pe-onukwilip-xyz
  dns_name    = "${var.subdomain}.${var.root_domain}."                   # pe.onukwilip.xyz.
  description = "Public managed zone for ${var.subdomain}.${var.root_domain}"
  visibility  = "public"
  project = var.host_project_id
}

resource "google_dns_managed_zone" "private_zone" {
  name        = replace("${var.private_subdomain}-${var.subdomain}-${var.root_domain}", ".", "-") # internal-pe-onukwilip-xyz
  dns_name    = "${var.private_subdomain}.${var.subdomain}.${var.root_domain}."                   # internal.pe.onukwilip.xyz.
  description = "Private managed zone for ${var.private_subdomain}.${var.subdomain}.${var.root_domain}"
  visibility  = "private"
  project = var.host_project_id

  private_visibility_config {
    networks {
      network_url = var.private_dns_network
    }
  }
}


