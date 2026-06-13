output "medium_priority_class_name" {
  description = "Name of the medium-priority PriorityClass (value: 1000). Used by observability and control-plane workloads."
  value       = kubernetes_priority_class.medium.metadata[0].name
}

output "high_priority_class_name" {
  description = "Name of the high-priority PriorityClass (value: 10000). Used by traffic-path gateway pods."
  value       = kubernetes_priority_class.high.metadata[0].name
}

output "postgres_priority_class_name" {
  description = "Name of the postgres-cluster-high PriorityClass (value: 100000). Used exclusively by the CNPG postgres cluster."
  value       = kubernetes_priority_class.postgres_cluster_high.metadata[0].name
}
