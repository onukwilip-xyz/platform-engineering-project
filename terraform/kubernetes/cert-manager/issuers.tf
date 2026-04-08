# ClusterIssuers live in terraform/kubernetes/cert-manager-config/
#
# They are a separate Terragrunt unit so that run-all apply applies this
# module first (registering the ClusterIssuer CRD via Helm), then applies
# cert-manager-config (creating the ClusterIssuer CRs against the now-live CRD).
#
# kubernetes_manifest validates manifests against the live CRD schema at plan
# time — if the CRD doesn't exist yet, the plan fails. Splitting into two units
# ensures the CRD is always registered before the CRs are planned.