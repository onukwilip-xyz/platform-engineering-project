resource "kubernetes_namespace" "cnpg_system" {
  metadata {
    name = "cnpg-system"
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}