output "public_gateway_namespace" {
  description = "Namespace where the public Istio gateway is deployed. HTTPRoute resources for public apps reference this."
  value       = kubernetes_namespace.istio_ingress.metadata[0].name
}

output "internal_gateway_namespace" {
  description = "Namespace where the internal Istio gateway is deployed. HTTPRoute resources for private apps reference this."
  value       = kubernetes_namespace.istio_ingress_internal.metadata[0].name
}

output "public_gateway_name" {
  description = "Name of the public Gateway CR."
  value       = kubernetes_manifest.gateway_public.manifest.metadata.name
}

output "internal_gateway_name" {
  description = "Name of the private Gateway CR."
  value       = kubernetes_manifest.gateway_internal.manifest.metadata.name
}