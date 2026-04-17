data "http" "tcproute_crd" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/experimental/gateway.networking.k8s.io_tcproutes.yaml"
}

resource "kubectl_manifest" "tcproute_crd" {
  yaml_body = data.http.tcproute_crd.response_body
}