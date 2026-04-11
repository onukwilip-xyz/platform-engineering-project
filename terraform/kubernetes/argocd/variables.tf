variable "namespace" {
  type        = string
  description = "Kubernetes namespace to deploy ArgoCD into."
  default     = "argocd"
}

variable "argocd_chart_version" {
  type        = string
  description = "Version of the argo/argo-cd Helm chart. Check https://artifacthub.io/packages/helm/argo/argo-cd for the latest."
}

variable "argocd_domain" {
  type        = string
  description = "Hostname for the ArgoCD UI, e.g. argocd.internal.pe.onukwilip.xyz. Must fall under the private gateway's wildcard listener."
}

variable "private_gateway_name" {
  type        = string
  description = "Name of the private (internal) Gateway CR. Passed from istio-gateway outputs."
  default     = "private"
}

variable "private_gateway_namespace" {
  type        = string
  description = "Namespace of the private (internal) Gateway. Passed from istio-gateway outputs."
  default     = "istio-ingress-internal"
}