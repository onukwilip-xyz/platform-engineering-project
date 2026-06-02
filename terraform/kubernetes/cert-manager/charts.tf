resource "null_resource" "cert_manager_crds" {
  triggers = {
    chart_version = var.cert_manager_chart_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add jetstack https://charts.jetstack.io --force-update
      helm template cert-manager jetstack/cert-manager \
        --version ${self.triggers.chart_version} \
        --namespace cert-manager \
        --set crds.enabled=true \
        --no-hooks \
      | python3 -c 'import sys; docs=sys.stdin.read().split("\n---"); crds=[d for d in docs if "kind: CustomResourceDefinition" in d]; print("\n---".join(crds))' \
      | kubectl apply --server-side --force-conflicts -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      helm template cert-manager jetstack/cert-manager \
        --version ${self.triggers.chart_version} \
        --namespace cert-manager \
        --set crds.enabled=true \
        --no-hooks \
      | python3 -c 'import sys; docs=sys.stdin.read().split("\n---"); crds=[d for d in docs if "kind: CustomResourceDefinition" in d]; print("\n---".join(crds))' \
      | kubectl delete --ignore-not-found=true -f -
    EOT
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      crds = {
        enabled = false
      },
      serviceAccount = {
        name = var.cert_manager_k8s_service_account_name
        annotations = {
          "iam.gke.io/gcp-service-account" = google_service_account.cert_manager_dns.email
        }
      },
      extraArgs = ["--enable-gateway-api"]
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 1200

  depends_on = [
    null_resource.cert_manager_crds,
    kubernetes_namespace.cert_manager,
    google_service_account_iam_member.cert_manager_workload_identity,
  ]
}

resource "helm_release" "trust_manager" {
  name             = "trust-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "trust-manager"
  version          = var.trust_manager_chart_version
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      app = {
        trust = {
          namespace = kubernetes_namespace.cert_manager.metadata[0].name
        }
      }
      secretTargets = {
        enabled           = true
        authorizedSecrets = ["internal-ca-bundle"]
      }
    })
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [helm_release.cert_manager]
}
