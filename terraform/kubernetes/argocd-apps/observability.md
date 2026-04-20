Got it — keeping it simple. Here's the plan with only the hybrid-mode gotchas called out.

## Prometheus (namespace: `monitoring`)

Chart: `prometheus-community/kube-prometheus-stack` (Prometheus + Operator + kube-state-metrics + node-exporter). Skip bundled Grafana — install separately.

**Considerations for hybrid setup:**
- Label namespace `istio.io/dataplane-mode: ambient` — Prometheus in ambient means ztunnel transparently handles mTLS when scraping sidecar-enabled microservices
- Node-exporter uses `hostNetwork: true` — add pod label `istio.io/dataplane-mode: none` to opt it out of ambient (ambient can't redirect hostNetwork pods)
- Set `grafana.enabled: false` in Helm values (installing Grafana separately)
- Set `prometheusSpec.serviceMonitorSelectorNilUsesHelmValues: false` and same for PodMonitor — lets Prometheus discover monitors in other namespaces (grafana, logging, tracing, microservices)
- For sidecar-injected microservices, use `enablePrometheusMerge: true` (already in your istiod config) — scrape port `15020` path `/stats/prometheus` for merged app+Envoy metrics
- Persistent storage: PVC with `standard` StorageClass, retention 7d

## Grafana (namespace: `grafana`)

Chart: `grafana/grafana`

**Considerations for hybrid setup:**
- Label namespace `istio.io/dataplane-mode: ambient`
- Pre-configure datasources in Helm values pointing to cross-namespace services: `http://prometheus-operated.monitoring.svc:9090`, `http://loki-gateway.logging.svc`, `http://tempo.tracing.svc:3100`
- Cross-namespace ambient-to-ambient traffic works transparently — no config needed
- Create `HTTPRoute` attached to your existing `private` Gateway in `istio-ingress-internal`, hostname `grafana.internal.pe.onukwilip.xyz`
- Set `ingress.enabled: false` in Helm values — you're using Gateway API, not Ingress
- Set `grafana.ini.server.root_url` to match the HTTPRoute hostname or login redirects break
- Admin password: pull from a Kubernetes Secret via External Secrets, don't hardcode

## Loki + Promtail (namespace: `logging`)

Charts: `grafana/loki` (single-binary mode) + `grafana/promtail`

**Considerations for hybrid setup:**
- Label `logging` namespace `istio.io/dataplane-mode: ambient` for Loki
- **Promtail is tricky**: it's a DaemonSet with `hostPath` mounts reading `/var/log/pods/` — add `istio.io/dataplane-mode: none` label on the Promtail pod template to exclude it from ambient
- Promtail → Loki traffic: Promtail (non-ambient) sending to Loki (ambient) works — ztunnel on Loki's side accepts plaintext from outside the mesh
- Storage: use GCS backend, not PVC (cheaper, survives pod restarts, simpler ops) — needs Workload Identity on Loki's KSA
- Retention: `limits_config.retention_period: 168h` (7d)
- For sidecar-injected microservice logs, Promtail picks up both app stdout AND Envoy access logs from the same node — add a pipeline stage to label `{container="istio-proxy"}` separately so you can filter them out when noisy
- Set `loki.auth_enabled: false` (single-tenant setup)

## Kubernetes Event Exporter (namespace: `events`)

Chart: `bitnami/kubernetes-event-exporter` or the official `resmoio/kubernetes-event-exporter`

**Considerations for hybrid setup:**
- Label namespace `istio.io/dataplane-mode: ambient`
- Configure Loki as the sink: `http://loki-gateway.logging.svc/loki/api/v1/push`
- Cross-namespace ambient→ambient, works transparently
- Add stream label `source: kubernetes-event-exporter` so you can query `{source="kubernetes-event-exporter"}` in Grafana
- ClusterRole permissions needed: `get, list, watch` on `events` cluster-wide — the chart handles this

## Tracing (namespace: `tracing`)

Chart: `grafana/tempo` (single-binary mode). Skip Jaeger — Tempo integrates natively with Grafana.

**Considerations for hybrid setup:**
- Label namespace `istio.io/dataplane-mode: ambient`
- **Critical**: your microservices are sidecar-mode → spans come from Envoy sidecars via OTLP. Ambient namespaces (observability stack itself) won't produce HTTP spans without waypoints — you probably don't care about tracing Grafana→Loki calls, so skip waypoints here
- Add Tempo as an extension provider in `istiod` `meshConfig`:
  ```yaml
  extensionProviders:
    - name: tempo-otel
      opentelemetry:
        service: tempo.tracing.svc.cluster.local
        port: 4317
  ```
- Create a mesh-wide `Telemetry` resource in `istio-system` pointing to `tempo-otel` with `randomSamplingPercentage: 100` for load testing (drop to 10% for prod)
- Storage: GCS backend, Workload Identity on Tempo's KSA
- Retention: 7d is plenty for debugging
- Make sure your microservices **propagate trace headers** (`traceparent`, `b3`, etc.) — without this, spans don't stitch together across hops, and no mesh config fixes that. Add OTel auto-instrumentation libraries: `@opentelemetry/auto-instrumentations-node` (Node), OTel Java agent (Spring Boot), `opentelemetry-instrumentation-fastapi` (Python)
- OTLP ports on Tempo service: `4317` (gRPC, what Istio uses), `4318` (HTTP)

## Cross-cutting considerations

- All 5 namespaces (`monitoring`, `grafana`, `logging`, `events`, `tracing`) are ambient — **no PeerAuthentication work needed**, ztunnel handles mTLS transparently
- Three pods need `istio.io/dataplane-mode: none` opt-out: **node-exporter**, **Promtail**, and any other hostNetwork DaemonSet
- Only Grafana needs an HTTPRoute through the `private` Gateway — everything else is cluster-internal
- Storage pattern: GCS + Workload Identity for Loki and Tempo; PVC for Prometheus only (Prometheus needs local-disk performance for query speed)
- Install order: Prometheus → Loki → Tempo → Grafana (needs the three datasources) → Promtail → Event Exporter → Istio Telemetry config

We could have a separate `observability` module in the `terraform/kubernetes` directory for provisioning the GCP resources or others which can't be managed by the ArgoCD applications.

The Helm charts and operators should be managed by the ArgoCD Applications