# The CA secret must live in the cert-manager namespace.
# ClusterIssuer CA secretName references are resolved from that namespace.
resource "kubernetes_secret" "ca" {
  metadata {
    name      = "cluster-ca-key-pair"
    namespace = var.cert_manager_namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.ca.cert_pem
    "tls.key" = tls_private_key.ca.private_key_pem
  }
}