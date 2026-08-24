# * POSTGRES CLUSTER

resource "kubernetes_namespace" "cnpg_system" {
  metadata {
    name = "cnpg-system"
    labels = {
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_namespace" "postgres" {
  metadata {
    name = "postgres"
    labels = {
      "istio-injection"                   = "disabled"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

# * OBSERVABILITY STACK

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "istio.io/dataplane-mode"           = "ambient"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "grafana"
    labels = {
      "istio.io/dataplane-mode"           = "ambient"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      "istio.io/dataplane-mode"           = "ambient"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_namespace" "tracing" {
  metadata {
    name = "tracing"
    labels = {
      "istio.io/dataplane-mode"           = "ambient"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_namespace" "events" {
  metadata {
    name = "events"
    labels = {
      "istio.io/dataplane-mode"           = "ambient"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

# * SECRET MANAGEMENT STACK

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
  timeouts {
    delete = "20m"
  }
}

# * MICROSERVICES STACK

resource "kubernetes_namespace" "users" {
  metadata {
    name = "users"
    labels = {
      "istio-injection"                   = "enabled"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_namespace" "store_ui" {
  metadata {
    name = "store-ui"
    labels = {
      "istio-injection"                   = "enabled"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}

# * LOAD TESTING STACK

resource "kubernetes_namespace" "load_testing" {
  metadata {
    name = "load-testing"
    labels = {
      "istio.io/dataplane-mode"           = "ambient"
      "trust.cert-manager.io/internal-ca" = "true"
    }
    annotations = {
      "argocd.argoproj.io/sync-wave" = "-1"
    }
  }
  timeouts {
    delete = "20m"
  }
}
