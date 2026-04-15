variable "argocd_namespace" {
  type        = string
  description = "Namespace where ArgoCD is installed. The App-of-Apps Application is created here."
  default     = "argocd"
}

variable "repo_url" {
  type        = string
  description = "Git repository URL ArgoCD tracks for the app-of-apps manifests path."
}

variable "target_revision" {
  type        = string
  description = "Git branch, tag, or commit SHA ArgoCD should track."
  default     = "HEAD"
}