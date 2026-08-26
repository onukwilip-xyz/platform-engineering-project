# Pre-destroy cleanup — runs before any Application or Namespace is deleted.
#
# Depends on every Application manifest and every Namespace so Terraform
# destroys this resource FIRST (reversed dependency order). The provisioner
# runs while all targets still exist, so every patch finds its object.
#
# Two-phase cleanup:
#   1. Strip ArgoCD Application finalizers  → Applications delete immediately
#      without waiting for ArgoCD cascade-deletion (which times out).
#   2. Strip operator-managed CR finalizers → Namespaces terminate cleanly even
#      when the operator that owns the finalizer has already been removed.
#      Targets known problem API groups rather than scanning every resource
#      (which would be slow and fragile).

resource "null_resource" "pre_destroy_cleanup" {
  triggers = {
    argocd_namespace = var.argocd_namespace
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-CMD
      # Phase 0 — delete operator-managed CRs while their operators are still alive
      # Kiali CR must be deleted before the kiali-operator gets torn down
      kubectl delete kiali --all -n tracing --wait=true --timeout=120s 2>/dev/null || true

      # Phase 1 — strip ArgoCD Application finalizers
      kubectl get applications.argoproj.io \
        -n ${self.triggers.argocd_namespace} -o name 2>/dev/null \
        | xargs -I {} kubectl patch {} \
            -n ${self.triggers.argocd_namespace} \
            --type=merge -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true

      # Phase 2 — strip operator-managed CR finalizers in every managed namespace
      for ns in postgres cnpg-system monitoring grafana logging tracing events external-secrets users store-ui load-testing; do
        for group in postgresql.cnpg.io kiali.io monitoring.coreos.com external-secrets.io; do
          kubectl api-resources --api-group="$group" --verbs=list --namespaced -o name 2>/dev/null \
            | xargs -I {} kubectl get {} -n "$ns" -o name 2>/dev/null \
            | xargs -I {} kubectl patch {} -n "$ns" \
                --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
      done
    CMD
  }

  depends_on = [
    # Applications
    kubernetes_manifest.cnpg_operator,
    kubernetes_manifest.postgres_cluster,
    kubernetes_manifest.kube_prometheus_stack,
    kubernetes_manifest.grafana,
    kubernetes_manifest.loki,
    kubernetes_manifest.alloy,
    kubernetes_manifest.tempo,
    kubernetes_manifest.kiali,
    kubernetes_manifest.jaeger,
    kubernetes_manifest.istio_telemetry,
    kubernetes_manifest.istio_monitors,
    kubernetes_manifest.kubernetes_event_exporter,
    kubernetes_manifest.external_secrets,
    kubernetes_manifest.users_microservice,
    kubernetes_manifest.store_ui,
    kubernetes_manifest.k6_operator,
    # Namespaces
    kubernetes_namespace.cnpg_system,
    kubernetes_namespace.postgres,
    kubernetes_namespace.monitoring,
    kubernetes_namespace.grafana,
    kubernetes_namespace.logging,
    kubernetes_namespace.tracing,
    kubernetes_namespace.events,
    kubernetes_namespace.external_secrets,
    kubernetes_namespace.users,
    kubernetes_namespace.store_ui,
    kubernetes_namespace.load_testing,
  ]
}