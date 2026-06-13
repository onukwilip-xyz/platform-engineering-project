resource "kubernetes_priority_class" "medium" {
  metadata {
    name = "medium-priority"
  }
  value             = 1000
  global_default    = false
  preemption_policy = "PreemptLowerPriority"
  description       = "Medium priority for platform control-plane workloads: Prometheus operator, Prometheus server, Grafana, CNPG operator, and Istio control plane (istiod)."
}

resource "kubernetes_priority_class" "high" {
  metadata {
    name = "high-priority"
  }
  value             = 10000
  global_default    = false
  preemption_policy = "PreemptLowerPriority"
  description       = "High priority for traffic-path gateway pods (Istio public and private ingress gateways). Protects them from preemption so in-flight connections are not interrupted."
}

resource "kubernetes_priority_class" "postgres_cluster_high" {
  metadata {
    name = "postgres-cluster-high"
  }
  value             = 100000
  global_default    = false
  preemption_policy = "PreemptLowerPriority"
  description       = "Highest priority reserved exclusively for the postgres-cluster pods. Protects DB pods from preemption and node-pressure eviction ahead of all other workloads."
}