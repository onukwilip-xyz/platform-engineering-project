variable "istio_chart_version" {
  type        = string
  description = "Version of the Istio Helm charts to install (base, istiod). All three charts must use the same version."
  default     = "1.24.2"
}

variable "tracing_namespace" {
  type        = string
  description = "Namespace where Tempo runs. Used to build the `tempo-otel` extensionProvider service address in istiod meshConfig."
  default     = "tracing"
}