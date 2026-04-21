resource "kubernetes_namespace" "cnpg_system" {
  metadata {
    name = "cnpg-system"
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}

resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "grafana"
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}

resource "kubernetes_namespace" "tracing" {
  metadata {
    name = "tracing"
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}

resource "kubernetes_namespace" "events" {
  metadata {
    name = "events"
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
}