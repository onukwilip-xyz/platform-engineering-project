locals {
  gke_mock_outputs = {
    gke_cluster_endpoint       = "127.0.0.1"
    gke_cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMFo1dnZaVThKVDNPUEZLL1NGRlYKTWREeGhsT3Y5WUNXcWpuQ3pTYk1PL05DNEpyVWU4SnlCeVlsRGNSaENsM0NmaGFSeGJaU0FwZElTeWREbgppWENscGJFaDVGL0pXVGhiTkZ0RXpJUVpYa3N4UVZvb3NOb0d6TUJVU3NXOE95UHVicmpjaFpuSTlIa1RHCkFQZlpERGhtZ3p4cmVDTUpvcFZ5aEdNVEE2blVMTFlOVk5ONjR4REVjUzZLc0xOdUhLMkpvbXh0UUlTRHkKdHZucUk1N0hhcGMyVHMxQTNnUHo0aXFhaFpFVFJsMFZYVktuYXFMRjFXZjk5OUVlNlpDVFY5YVdkaGhRTgpXZDlxV0QzWG5OZkdlQUlEN2pSUlRUcVBJQ2lScEZJbHdaTnJpMUkyYXZ3T29WTmNGcVJUWlVrSTQyVk1PClZ3SURBUUFCZ29BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBCkFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUEKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
    service_project_id         = "mock-service-project-id"
    host_project_id            = "mock-host-project-id"
    gke_subnet_self_link       = "https://www.googleapis.com/compute/v1/projects/mock-host-project-id/regions/us-central1/subnetworks/mock-gke-subnet"
    private_dns_zone_name      = "internal-pe-onukwilip-xyz"
  }

  project_mock_outputs = {
    service_project_id     = "mock-service-project-id"
    service_project_number = "000000000000"
  }

  istio_mock_outputs = {
    istio_chart_version = "1.24.2"
    gateway_class_name  = "istio"
  }

  cert_manager_mock_outputs = {
    namespace = "cert-manager"
  }

  cert_manager_config_mock_outputs = {
    public_cluster_issuer_name   = "letsencrypt-public"
    internal_cluster_issuer_name = "internal-ca"
  }

  istio_gateway_mock_outputs = {
    public_gateway_name        = "public"
    public_gateway_namespace   = "istio-ingress"
    internal_gateway_name      = "private"
    internal_gateway_namespace = "istio-ingress-internal"
    public_gateway_ip          = "1.2.3.4"
    private_gateway_ip         = "10.0.0.5"
  }

  argocd_mock_outputs = {
    namespace     = "argocd"
    argocd_domain = "argocd.internal.pe.onukwilip.xyz"
  }

  tcp_services_mock_outputs = {
    shared_vip_name    = "tcp-services-shared-vip"
    shared_vip_address = "10.0.0.100"
  }

  cnpg_infra_mock_outputs = {
    backup_bucket_name  = "mock-cnpg-postgres-backups"
    backup_gcp_sa_email = "cnpg-backup@mock-service-project-id.iam.gserviceaccount.com"
  }
}