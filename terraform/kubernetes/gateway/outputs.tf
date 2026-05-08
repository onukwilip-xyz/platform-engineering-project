output "public_gateway_namespace" {
  description = "Namespace where the public Gateway is deployed. HTTPRoute resources for public apps reference this."
  value       = kubernetes_namespace.istio_ingress.metadata[0].name
}

output "internal_gateway_namespace" {
  description = "Namespace where the internal Istio gateway is deployed. HTTPRoute resources for private apps reference this."
  value       = kubernetes_namespace.istio_ingress_internal.metadata[0].name
}

output "public_gateway_name" {
  description = "Name of the public Gateway CR (GKE Gateway class)."
  value       = kubernetes_manifest.gateway_public.manifest.metadata.name
}

output "internal_gateway_name" {
  description = "Name of the private Gateway CR (Istio class)."
  value       = kubernetes_manifest.gateway_internal.manifest.metadata.name
}

output "public_gateway_global_ip" {
  description = "Global external IP address fronting the public Gateway via Google Cloud's HTTPS LB."
  value       = google_compute_global_address.public_gateway.address
}

output "public_gateway_ip" {
  description = "Alias for public_gateway_global_ip — kept under the legacy name so existing dependents (DNS records, mocks) continue to resolve."
  value       = google_compute_global_address.public_gateway.address
}

output "private_gateway_ip" {
  description = "Static internal IP address assigned to the private Istio gateway LoadBalancer service."
  value       = google_compute_address.private_gateway.address
}