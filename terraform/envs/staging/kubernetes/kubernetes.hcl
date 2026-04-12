locals {
  gke_mock_outputs = {
    gke_cluster_endpoint       = "127.0.0.1"
    gke_cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMFo1dnZaVThKVDNPUEZLL1NGRlYKTWREeGhsT3Y5WUNXcWpuQ3pTYk1PL05DNEpyVWU4SnlCeVlsRGNSaENsM0NmaGFSeGJaU0FwZElTeWREbgppWENscGJFaDVGL0pXVGhiTkZ0RXpJUVpYa3N4UVZvb3NOb0d6TUJVU3NXOE95UHVicmpjaFpuSTlIa1RHCkFQZlpERGhtZ3p4cmVDTUpvcFZ5aEdNVEE2blVMTFlOVk5ONjR4REVjUzZLc0xOdUhLMkpvbXh0UUlTRHkKdHZucUk1N0hhcGMyVHMxQTNnUHo0aXFhaFpFVFJsMFZYVktuYXFMRjFXZjk5OUVlNlpDVFY5YVdkaGhRTgpXZDlxV0QzWG5OZkdlQUlEN2pSUlRUcVBJQ2lScEZJbHdaTnJpMUkyYXZ3T29WTmNGcVJUWlVrSTQyVk1PClZ3SURBUUFCZ29BQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBCkFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUEKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
    service_project_id         = "mock-service-project-id"
    host_project_id            = "mock-host-project-id"
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
  }
}