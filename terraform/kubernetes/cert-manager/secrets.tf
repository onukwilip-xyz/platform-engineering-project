resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "ca" {
  metadata {
    name      = "cluster-ca-key-pair"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.ca.cert_pem
    "tls.key" = tls_private_key.ca.private_key_pem
  }

  depends_on = [kubernetes_namespace.cert_manager]
}
