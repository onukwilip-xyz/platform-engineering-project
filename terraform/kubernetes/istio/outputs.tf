output "istio_system_namespace" {
  description = "Name of the istio-system namespace. Consumed by downstream units (gateway-api, istio-gateway)."
  value       = kubernetes_namespace.istio_system.metadata[0].name
}

output "istio_chart_version" {
  description = "Installed Istio chart version. Re-exported so the gateway unit pins the same version."
  value       = var.istio_chart_version
}

output "gateway_class_name" {
  description = "Name of the GatewayClass automatically created by istiod on startup. Always 'istio' — depends_on ensures istiod is running before this output is consumed."
  value       = "istio"
  depends_on  = [helm_release.istiod]
}