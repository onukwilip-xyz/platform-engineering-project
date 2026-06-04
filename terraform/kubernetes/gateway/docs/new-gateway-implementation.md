# SLO + Gateway Implementation Plan

---

## Part 1 — Fix Sloth SLI Queries to Use Available Metrics

### Background

The Sloth recording rules are generating `NoData` because the SLO queries
filter on `reporter="destination"`, but the only available
`istio_requests_total` series with a correct `destination_service_name` label
come from `reporter="source"` (emitted by the Istio ingress gateway's Envoy).

`reporter="destination"` only returns `InboundPassthroughCluster` because
Prometheus (ambient-mode, ztunnel-only) scrapes the pods via ztunnel, which
strips service identity from the inbound sidecar's view.

Switching to `reporter="source"` is correct because:
- The Istio ingress gateway IS the canonical entry point for all application traffic
- It records `destination_service_name` accurately
- It covers 100% of real user requests for both services under the current architecture

---

### 1.1 — Update `users-microservice` SLO

**File:** `helm/users-microservice/templates/slo.yaml`

Change both SLOs from `reporter="destination"` to `reporter="source"`.

#### Availability SLO

```yaml
sli:
  events:
    errorQuery: >-
      sum(rate(istio_requests_total{
        reporter="source",
        destination_service_name="{{ .Values.service.name }}",
        destination_service_namespace="{{ .Release.Namespace }}"
      }[{{`{{.window}}`}}]))
      -
      sum(rate(istio_requests_total{
        reporter="source",
        destination_service_name="{{ .Values.service.name }}",
        destination_service_namespace="{{ .Release.Namespace }}",
        response_code=~"[1234]..",
        response_flags="-"
      }[{{`{{.window}}`}}]))
    totalQuery: >-
      sum(rate(istio_requests_total{
        reporter="source",
        destination_service_name="{{ .Values.service.name }}",
        destination_service_namespace="{{ .Release.Namespace }}"
      }[{{`{{.window}}`}}]))
```

#### Latency SLO

```yaml
sli:
  events:
    errorQuery: >-
      sum(rate(istio_requests_total{
        reporter="source",
        destination_service_name="{{ .Values.service.name }}",
        destination_service_namespace="{{ .Release.Namespace }}"
      }[{{`{{.window}}`}}]))
      -
      sum(rate(istio_request_duration_milliseconds_bucket{
        reporter="source",
        destination_service_name="{{ .Values.service.name }}",
        destination_service_namespace="{{ .Release.Namespace }}",
        le="{{ .Values.slo.latency.thresholdMs }}"
      }[{{`{{.window}}`}}]))
    totalQuery: >-
      sum(rate(istio_requests_total{
        reporter="source",
        destination_service_name="{{ .Values.service.name }}",
        destination_service_namespace="{{ .Release.Namespace }}"
      }[{{`{{.window}}`}}]))
```

---

### 1.2 — Update `store-ui` SLO

**File:** `helm/store-ui/templates/slo.yaml`

Same changes as above. The store-ui currently has NO `reporter="source"` series
at all (only `InboundPassthroughCluster` from Prometheus scraping), because the
public GKE LB bypasses Istio entirely and goes direct to pods via NEG.

**Implication:** The store-ui SLO recording rules will still return `NoData`
until Part 2 (new gateway architecture) is implemented and traffic flows through
the public Istio gateway. Apply the `reporter="source"` change now regardless —
the queries are correct and will start producing data once the gateway is in place.

Apply the exact same errorQuery / totalQuery / latency changes as users-microservice,
substituting `store-ui-service` for the service name.

---

### 1.3 — Verify after ArgoCD sync

ArgoCD detects the Helm chart changes and syncs the updated
`PrometheusServiceLevel` CRs. Sloth regenerates the `PrometheusRule` resources
within ~30 seconds.

```bash
# 1. Confirm new PrometheusRule uses reporter="source"
kubectl get prometheusrule users-microservice -n users -o yaml | grep reporter

# 2. Check recording rules are now producing values in Prometheus
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
# Query: slo:sli_error:ratio_rate5m{sloth_service="users-microservice"}
# Should return a numeric value (not NoData)

# 3. Confirm Grafana SLO alerts move from NoData → Normal
# Alerting → Alert rules → slo-alerts group
# All users-microservice rules should show Health: ok, State: Normal

# 4. Confirm store-ui still shows NoData (expected until Part 2)
# slo:sli_error:ratio_rate5m{sloth_service="store-ui"}  → no data
```

---

### Part 1 — Summary of file changes

| File | Change |
|---|---|
| `helm/users-microservice/templates/slo.yaml` | `reporter="destination"` → `reporter="source"` in all 4 queries |
| `helm/store-ui/templates/slo.yaml` | Same change — queries correct, data arrives after Part 2 |

No Grafana alert rule changes needed — the recording rule metric names
(`slo:sli_error:ratio_rate*`) are identical regardless of the underlying reporter.

---
---

## Part 2 — New Public Gateway Architecture

### Background

**Current architecture:**
```
Internet → GKE Gateway (ALB + Cloud Armor) → store-ui pods (direct via NEG)
```
Problems:
- No Istio Envoy in the path → no `istio_requests_total` for store-ui
- store-ui SLO has no data source
- Destination sidecar sees `InboundPassthroughCluster` (not the real service name)

**Target architecture:**
```
Internet
  ↓
GKE Gateway (ALB + Cloud Armor) — unchanged, stays in gke-ingress ns
  ↓  Single HTTPRoute: *.pe.onukwilip.xyz → public Istio gateway svc
New Public Istio Gateway (ClusterIP, no NLB) — new, istio-ingress-public ns
  ↓  Per-service HTTPRoutes in their own namespaces
store-ui pods (now Istio Envoy in path → SLI metrics available)
```

**Why no ReferenceGrant needed:**
The GKE Gateway HTTPRoute lives in `istio-ingress-public` ns and its backendRef
points to the public Istio gateway Service which is ALSO in `istio-ingress-public`
ns. Same namespace = no ReferenceGrant required. This is the same pattern as
all other existing HTTPRoutes in the codebase.

---

### 2.1 — New namespace

**File:** `terraform/kubernetes/gateway/gateways.tf` (or namespaces.tf if separated)

```hcl
resource "kubernetes_namespace" "istio_ingress_public" {
  metadata {
    name = "istio-ingress-public"
    labels = {
      # Gateway pod IS Envoy — it does not need its own sidecar
      "istio.io/dataplane-mode" = "none"
    }
  }
}
```

---

### 2.2 — Public Istio Gateway CR

**File:** `terraform/kubernetes/gateway/gateways.tf`

```hcl
resource "kubernetes_manifest" "public_istio_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = kubernetes_namespace.istio_ingress_public.metadata[0].name
      annotations = {
        # Prevents Istio from provisioning an NLB for this gateway.
        # The GKE Gateway (ALB) is the only public entry point.
        # Istio creates a ClusterIP Service + Envoy Deployment only.
        "networking.istio.io/service-type" = "ClusterIP"
      }
    }
    spec = {
      gatewayClassName = var.gateway_class_name   # "istio"
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            # Any namespace can attach HTTPRoutes to this gateway
            namespaces = { from = "All" }
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace.istio_ingress_public]
}
```

---

### 2.3 — Single GKE Gateway HTTPRoute (wildcard passthrough)

**File:** `terraform/kubernetes/gateway/httproutes.tf`
(or wherever the existing GKE Gateway HTTPRoutes live)

This replaces the existing direct GKE → `store-ui-service` HTTPRoute.

```hcl
resource "kubernetes_manifest" "gke_to_public_istio_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "public-to-istio"
      # Lives in istio-ingress-public ns — same ns as the backend Service
      # so no ReferenceGrant is needed
      namespace = kubernetes_namespace.istio_ingress_public.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          # Attaches to existing GKE Gateway (ALB + Cloud Armor)
          name      = var.public_gateway_name
          namespace = var.public_gateway_namespace   # gke-ingress
        }
      ]
      # Wildcard catches all subdomains on the public domain.
      # This rule never needs to change when new services are added.
      hostnames = ["*.${var.public_domain}"]
      rules = [
        {
          backendRefs = [
            {
              # Istio auto-provisions this Service when the Gateway CR is created.
              # Named after the Gateway resource: "public"
              name      = "public"
              namespace = kubernetes_namespace.istio_ingress_public.metadata[0].name
              port      = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.public_istio_gateway]
}
```

---

### 2.4 — Per-service HTTPRoutes on the public Istio Gateway

Each service gets its own HTTPRoute in its own namespace, attached to the public
Istio gateway. Routing decisions live entirely on the Istio side.

**store-ui HTTPRoute**

**File:** `helm/store-ui/templates/httproute-public.yaml`
(or the existing virtualservice/httproute template if the chart already has one)

```yaml
{{- if .Values.publicGateway.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ .Values.service.name }}-public
  namespace: {{ .Release.Namespace }}
spec:
  parentRefs:
    - name: public
      namespace: {{ .Values.publicGateway.namespace }}  # istio-ingress-public
  hostnames:
    - {{ .Values.service.externalHost }}               # store-ui.pe.onukwilip.xyz
  rules:
    - backendRefs:
        - name: {{ .Values.service.name }}             # store-ui-service
          port: {{ .Values.service.port }}
{{- end }}
```

Add to `helm/store-ui/values.yaml`:

```yaml
publicGateway:
  enabled: true
  namespace: istio-ingress-public
```

**Repeat for any other services that need public exposure in future** — each
gets its own HTTPRoute template with `publicGateway.enabled` flag.

---

### 2.5 — Remove old direct GKE → store-ui HTTPRoute

**File:** `terraform/kubernetes/gateway/httproutes.tf` (or wherever it lives)

Delete or comment out the existing HTTPRoute that pointed the GKE Gateway
directly at `store-ui-service`. It is fully replaced by `2.3` + `2.4`.

---

### 2.6 — Verify after apply

```bash
# 1. Public Istio gateway pods running (no external IP — ClusterIP only)
kubectl get svc -n istio-ingress-public
# NAME     TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)
# public   ClusterIP   10.x.x.x      <none>        80/TCP

# 2. GKE Gateway HTTPRoute accepted
kubectl get httproute public-to-istio -n istio-ingress-public -o yaml | grep -A5 status
# conditions:
#   - type: Accepted
#     status: "True"

# 3. store-ui HTTPRoute accepted on public Istio gateway
kubectl get httproute store-ui-service-public -n store-ui -o yaml | grep -A5 status

# 4. Send a test request through the public domain
curl -v https://store-ui.pe.onukwilip.xyz/health

# 5. Confirm Istio metrics now exist for store-ui with correct service name
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
# Query:
# count by (reporter, destination_service_name) (
#   istio_requests_total{destination_service_namespace="store-ui"}
# )
# Expected new row: {destination_service_name="store-ui-service", reporter="source"}

# 6. Confirm store-ui Sloth recording rules now produce values
# Query: slo:sli_error:ratio_rate5m{sloth_service="store-ui"}
# Should return a numeric value within ~1 minute of traffic

# 7. Grafana slo-alerts group — all 10 rules now show Normal (not NoData)
```

---

### Part 2 — Summary of file changes

| File | Change |
|---|---|
| `terraform/kubernetes/gateway/gateways.tf` | Add `istio-ingress-public` namespace + `public` Istio Gateway CR |
| `terraform/kubernetes/gateway/httproutes.tf` | Add wildcard GKE→Istio HTTPRoute; remove old direct GKE→store-ui HTTPRoute |
| `helm/store-ui/templates/httproute-public.yaml` | New file — HTTPRoute on public Istio gateway → store-ui-service |
| `helm/store-ui/values.yaml` | Add `publicGateway:` block |

The GKE Gateway itself, its Cloud Armor security policy, the private Istio
gateway, and all existing users-microservice HTTPRoutes remain completely
unchanged.