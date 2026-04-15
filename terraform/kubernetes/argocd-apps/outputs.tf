output "app_of_apps_name" {
  description = "Name of the root App-of-Apps ArgoCD Application."
  value       = kubernetes_manifest.app_of_apps.manifest.metadata.name
}