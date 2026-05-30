# * GRAFANA

resource "kubernetes_config_map" "grafana_alerting_contactpoints" {
  metadata {
    name      = "grafana-alerting-contactpoints"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_alert = "1"
    }
  }

  data = {
    "contactpoints.yaml" = file("${path.module}/grafana-alerting/contactpoints.yaml")
  }
}

resource "kubernetes_config_map" "grafana_alerting_policies" {
  metadata {
    name      = "grafana-alerting-policies"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_alert = "1"
    }
  }

  data = {
    "policies.yaml" = file("${path.module}/grafana-alerting/policies.yaml")
  }
}

resource "kubernetes_config_map" "grafana_alerting_rules" {
  metadata {
    name      = "grafana-alerting-rules"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_alert = "1"
    }
  }

  data = {
    "rules.yaml" = templatefile("${path.module}/grafana-alerting/rules.yaml", {
      critical_namespaces = local.critical_namespaces
    })
  }
}

resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = local.dashboard_folders

  metadata {
    name      = "dashboard-${lower(replace(trimsuffix(each.key, ".json"), " ", "-"))}"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = each.value
    }
  }

  data = {
    "${each.key}" = file("${path.module}/grafana-dashboards/${each.key}")
  }
}

# * USER MICROSERVICE

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

# * LOAD TESTING

resource "kubernetes_config_map" "load_testing_script" {
  metadata {
    name      = "k6-write-heavy"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
  }

  data = {
    "write-heavy.js" = file("${path.module}/../../load-testing/scripts/write-heavy.js")
  }
}