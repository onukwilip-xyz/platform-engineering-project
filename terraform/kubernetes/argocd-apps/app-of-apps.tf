# Root App-of-Apps — a single ArgoCD Application that watches the
# argocd-apps/manifests/ directory in this repo. Any Application CR dropped
# into that directory is automatically picked up and synced by ArgoCD,
# making it the single entry-point for all GitOps-managed workloads.
resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = "terraform/kubernetes/argocd-apps/manifests"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=false", "ServerSideApply=true"]
      }
    }
  }
}