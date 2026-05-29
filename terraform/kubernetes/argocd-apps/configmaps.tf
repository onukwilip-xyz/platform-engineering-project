# * GRAFANA DASHBOARDS
# One ConfigMap per JSON file in grafana-dashboards/. The sidecar watches for
# the grafana_dashboard=1 label and hot-loads each file into the folder named
# by the grafana_folder annotation. Add new dashboards by dropping JSON files
# into grafana-dashboards/ and adding an entry to local.dashboard_folders.

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

resource "kubernetes_config_map" "load_testing_script" {
  metadata {
    name      = "k6-write-heavy"
    namespace = kubernetes_namespace.load_testing.metadata[0].name
  }

  data = {
    "write-heavy.js" = file("${path.module}/../../load-testing/scripts/write-heavy.js")
  }
}