resource "kubernetes_config_map" "users_microservice" {
  metadata {
    name      = "users-config"
    namespace = kubernetes_namespace.users.metadata[0].name
  }

  data = {
    APP_HOST        = "0.0.0.0"
    APP_PORT        = "9090"
    LOG_LEVEL       = "info"
    SEED_ON_STARTUP = "false"
  }
}