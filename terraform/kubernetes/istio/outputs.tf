output "istio_system_namespace" {
  description = "Name of the istio-system namespace. Consumed by downstream units (gateway-api, istio-gateway)."
  value       = kubernetes_namespace.istio_system.metadata[0].name
}

output "istio_chart_version" {
  description = "Installed Istio chart version. Re-exported so the gateway unit pins the same version."
  value       = var.istio_chart_version
}