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
  description = "Git branch, tag, or commit SHA ArgoCD should track. Typically sourced from the CD pipeline's branch context (e.g. TF_VAR_target_revision=staging)."
  default     = "HEAD"
}

variable "backup_gcp_sa_email" {
  type        = string
  description = "Email of the GCP SA for CNPG backup via Workload Identity."
}

variable "backup_bucket_name" {
  type        = string
  description = "GCS bucket name for CNPG Barman backups."
}

variable "shared_vip_address" {
  type        = string
  description = "IP address of the tcp-services shared VIP for the pooler LoadBalancer."
}

variable "cluster_issuer_name" {
  type        = string
  description = "cert-manager ClusterIssuer name for PostgreSQL TLS certificates."
  default     = "internal-ca"
}

variable "cnpg_operator_chart_version" {
  type        = string
  description = "Pinned version of the cloudnative-pg Helm chart. Bump via PR to roll the operator forward."
  default     = "0.23.0"
}

variable "kube_prometheus_stack_chart_version" {
  type        = string
  description = "Pinned version of the prometheus-community/kube-prometheus-stack Helm chart. Bump via PR to roll Prometheus + Operator + kube-state-metrics + node-exporter forward."
  default     = "83.6.0"
}

variable "private_domain" {
  type        = string
  description = "Root DNS name for internal services (e.g. internal.example.com). Used to build Grafana's root_url so login redirects resolve to the private Gateway hostname."
}

variable "public_domain" {
  type        = string
  description = "Root DNS name for public-facing services (e.g. example.com). Used to build hostnames for HTTPRoutes attached to the public Istio Gateway (e.g. store.<public_domain>)."
}

variable "public_gateway_name" {
  type        = string
  description = "Name of the public Istio Gateway CR. HTTPRoutes for internet-facing services reference this as parentRef."
  default     = "public"
}

variable "public_gateway_namespace" {
  type        = string
  description = "Namespace where the public Istio Gateway lives. Sourced from the istio-gateway module output."
}

variable "private_gateway_name" {
  type        = string
  description = "Name of the internal Istio Gateway CR. HTTPRoutes for internal services reference this as parentRef."
  default     = "private"
}

variable "private_gateway_namespace" {
  type        = string
  description = "Namespace where the internal Istio Gateway lives. Sourced from the istio-gateway module output."
}

variable "loki_chart_version" {
  type        = string
  description = "Pinned version of the grafana/loki Helm chart. Bump via PR to roll Loki forward."
  default     = "6.55.0"
}

variable "alloy_chart_version" {
  type        = string
  description = "Pinned version of the grafana/alloy Helm chart. Bump via PR to roll the log collector forward."
  default     = "1.7.0"
}

variable "loki_gcs_bucket_name" {
  type        = string
  description = "GCS bucket name Loki writes chunks, index, and rulers to. Sourced from observability-infra."
}

variable "loki_gcs_sa_email" {
  type        = string
  description = "Email of the GCP SA Loki impersonates via WIF. Used to annotate Loki's KSA. Sourced from observability-infra."
}

variable "tempo_chart_version" {
  type        = string
  description = "Pinned version of the grafana/tempo (single binary) Helm chart. Bump via PR to roll Tempo forward."
  default     = "2.0.0"
}

variable "tempo_gcs_bucket_name" {
  type        = string
  description = "GCS bucket name Tempo writes trace blocks to. Sourced from observability-infra."
}

variable "tempo_gcs_sa_email" {
  type        = string
  description = "Email of the GCP SA Tempo impersonates via WIF. Used to annotate Tempo's KSA. Sourced from observability-infra."
}

variable "tracing_sampling_percentage" {
  type        = number
  description = "Percent of requests the mesh-wide Istio Telemetry CR samples for tracing. 100 for staging/load tests; drop to ~10 for prod."
  default     = 100
}

variable "kubernetes_event_exporter_chart_version" {
  type        = string
  description = "Pinned version of the resmoio/kubernetes-event-exporter Helm chart. Bump via PR to roll the exporter forward."
  default     = "3.2.12"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster. Used to label events the kubernetes-event-exporter ships to Loki so multi-cluster dashboards can filter by origin."
}

variable "external_secrets_chart_version" {
  type        = string
  description = "Pinned version of the external-secrets Helm chart. Bump via PR to roll the operator forward."
  default     = "2.3.0"
}

# ── Microservices ─────────────────────────────────────────────────────────────

variable "service_project_id" {
  type        = string
  description = "GCP project ID hosting the Artifact Registry Docker repo the microservice images are pushed to."
}

variable "region" {
  type        = string
  description = "The project resources region for artifact registry (e.g. us-central1). Must match the region the images were pushed to."
}

variable "artifact_registry_images_repo_id" {
  type        = string
  description = "Artifact Registry repository ID for Docker images. Must match the repo provisioned by the artifact-registry module."
}

variable "users_microservice_image_tag" {
  type        = string
  description = "Tag of the users microservice Docker image to deploy. Bump here to roll out a new version."
  default     = "v1"
}

variable "store_ui_image_tag" {
  type        = string
  description = "Tag of the store-ui Docker image to deploy. Bump here to roll out a new version."
  default     = "v1"
}

# ── Load Testing ─────────────────────────────────────────────────────────────

variable "k6_operator_chart_version" {
  type        = string
  description = "Pinned version of the grafana/k6-operator Helm chart. Bump via PR to roll the operator forward."
  default     = "4.3.2"
}