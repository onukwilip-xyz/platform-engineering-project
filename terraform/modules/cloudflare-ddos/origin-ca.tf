resource "tls_private_key" "origin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "origin" {
  private_key_pem = tls_private_key.origin.private_key_pem

  subject {
    common_name  = var.cloudflare_public_domain
    organization = "Platform Engineering"
  }
}

resource "cloudflare_origin_ca_certificate" "origin" {
  csr                = tls_cert_request.origin.cert_request_pem
  hostnames          = ["*.${var.cloudflare_public_domain}"]
  request_type       = "origin-rsa"
  requested_validity = 365
}