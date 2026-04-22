# Enable ztunnel DaemonSet to run with higher priority
resource "kubernetes_resource_quota" "istio_system_critical_pods" {
  metadata {
    name      = "critical-pods"
    namespace = kubernetes_namespace.istio_system.metadata[0].name
  }

  spec {
    hard = {
      pods = "1000"
    }

    scope_selector {
      match_expression {
        operator   = "In"
        scope_name = "PriorityClass"
        values     = ["system-node-critical", "system-cluster-critical"]
      }
    }
  }
}