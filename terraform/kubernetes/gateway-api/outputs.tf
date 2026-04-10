output "istio_gateway_class_name" {
  description = "Name of the Istio GatewayClass. Referenced by Gateway resources in the istio-gateway module."
  value       = kubernetes_manifest.gateway_class_istio.manifest.metadata.name
}