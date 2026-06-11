resource "kubernetes_limit_range" "cnpg_system" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.cnpg_system.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "postgres" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "monitoring" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "grafana" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "logging" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "tracing" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.tracing.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "events" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.events.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "external_secrets" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "users" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.users.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "store_ui" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.store_ui.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}

resource "kubernetes_limit_range" "load_testing" {
  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "120m"
        memory = "150Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "100Mi"
      }
    }
  }
}
