variable "istio_chart_version" {
  type        = string
  description = "Version of the Istio Helm charts to install (base, istiod). All three charts must use the same version."
  default     = "1.24.2"
}

variable "otel_collector_address" {
  type        = string
  description = "gRPC address of the OpenTelemetry collector for trace export (host:port). Spans are dropped silently if the collector is unreachable — safe to set before the monitoring module exists."
  default     = "otel-collector.monitoring:4317"
}