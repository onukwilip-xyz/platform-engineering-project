resource "kubernetes_secret" "cf_origin_tls" {
  metadata {
    name      = "cf-origin-tls"
    namespace = var.istio_namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = cloudflare_origin_ca_certificate.origin.certificate
    "tls.key" = tls_private_key.origin.private_key_pem
  }
}