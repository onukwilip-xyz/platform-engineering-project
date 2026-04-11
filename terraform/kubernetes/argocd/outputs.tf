output "namespace" {
  description = "The ArgoCD namespace. Consumed by downstream units that need to deploy into or reference the argocd namespace."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_domain" {
  description = "The hostname at which ArgoCD is reachable via the private gateway."
  value       = var.argocd_domain
}