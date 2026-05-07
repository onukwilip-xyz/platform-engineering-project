## TL;DR — what's already exposing metrics, what needs work

| Component | Metrics endpoint exposed? | ServiceMonitor shipped? | Action needed |
|---|---|---|---|
| **Istio sidecars (microservices)** | ✅ Port 15020 (merged) | ❌ Need to create | Create PodMonitor |
| **Istio control plane (istiod)** | ✅ Port 15014 | ❌ Need to create | Create ServiceMonitor |
| **Istio Gateways** | ✅ Port 15020 | ❌ Need to create | Create PodMonitor |
| **Ztunnel (ambient)** | ✅ Port 15020 | ❌ Need to create | Create PodMonitor |
| **CNPG Postgres** | ✅ Port 9187 (built-in exporter) | ✅ Operator creates PodMonitors | Enable via `monitoring.enablePodMonitor: true` |
| **PGBouncer (CNPG pooler)** | ✅ Port 9127 (built-in exporter) | ✅ Operator creates PodMonitors | Same Cluster `monitoring` flag |
| **k6 test runs** | ⚠️ Optional via remote-write | ❌ n/a | Configure Prometheus remote-write in TestRun |

Good news: **all four need almost no custom code** — CNPG ships metrics out of the box, Istio ships metrics out of the box. You just need to tell Prometheus "go scrape them" via ServiceMonitor/PodMonitor CRs.

## 1. CNPG Postgres + PGBouncer metrics

CNPG has **first-class Prometheus integration**. The operator already exposes metrics on port 9187 for each Postgres instance and port 9127 for each PGBouncer pooler pod. You just need to enable PodMonitor creation.

**Update your Postgres `Cluster` manifest** (in `terraform/kubernetes/manifests/postgres`):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
  namespace: postgres
spec:
  # ... your existing config ...
  monitoring:
    enablePodMonitor: true  # ← This is the key flag
    # Optional: add custom queries
    # customQueriesConfigMap:
    #   - name: cnpg-custom-queries
    #     key: queries.yaml
```

**And your `Pooler` manifest** for PGBouncer:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: postgres-pooler-rw
  namespace: postgres
spec:
  cluster:
    name: postgres-cluster
  instances: 3
  type: rw
  monitoring:
    enablePodMonitor: true  # ← Same flag for the pooler
  pgbouncer:
    poolMode: session  # or transaction
    # ... rest of config ...
```

Once applied, the CNPG operator creates PodMonitors automatically. Your kube-prometheus-stack Prometheus will pick them up (assuming `podMonitorSelectorNilUsesHelmValues: false` as I suggested earlier).

**Dashboards to import:**
- **CNPG Cluster dashboard**: Grafana ID **20417** — official CloudNativePG dashboard (disks, IOPs, WAL, replication lag, connections)
- **PGBouncer dashboard**: Grafana ID **7419** — classic PGBouncer dashboard (pools, waiting clients, query duration). Works with the CNPG pooler's metrics.

Verify metrics are flowing:
```bash
kubectl get podmonitor -n postgres
# Expect: postgres-cluster, postgres-pooler-rw
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090
# Visit http://localhost:9090/targets — filter for "postgres"
```

## 2. Istio metrics (sidecars, istiod, gateways, ztunnel)

Your `enablePrometheusMerge: true` config means sidecars already serve merged app+Envoy metrics at port 15020. You just need PodMonitors/ServiceMonitors to scrape them.

**Create these CRs** in a dedicated ArgoCD Application for observability config. Here's the full set:

```yaml
# istio-podmonitor.yaml — scrapes sidecar-injected pods across all namespaces
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: envoy-stats
  namespace: monitoring
  labels:
    release: kube-prometheus-stack  # needed so your Prometheus picks it up
spec:
  namespaceSelector:
    any: true
  selector:
    matchExpressions:
      - key: istio-prometheus-ignore
        operator: DoesNotExist
  podMetricsEndpoints:
    - path: /stats/prometheus
      interval: 15s
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_container_name]
          action: keep
          regex: "istio-proxy"
        - sourceLabels: [__meta_kubernetes_pod_annotationpresent_prometheus_io_scrape]
          action: keep
          regex: "true"
        - sourceLabels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          targetLabel: __address__
```

```yaml
# istiod-servicemonitor.yaml — scrapes the control plane
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istiod
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - istio-system
  selector:
    matchLabels:
      istio: pilot
  endpoints:
    - port: http-monitoring  # port 15014
      interval: 15s
```

```yaml
# istio-gateway-podmonitor.yaml — scrapes the gateway deployments
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-gateways
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - istio-ingress
      - istio-ingress-internal
  selector:
    matchLabels:
      istio.io/gateway-name: private  # adjust to match your gateway labels
  podMetricsEndpoints:
    - path: /stats/prometheus
      interval: 15s
```

```yaml
# ztunnel-podmonitor.yaml — scrapes the ambient ztunnel DaemonSet
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: ztunnel
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - istio-system
  selector:
    matchLabels:
      app: ztunnel
  podMetricsEndpoints:
    - path: /metrics
      port: stats-prom
      interval: 15s
```

**Dashboards to import:**
- **Istio Service Dashboard**: ID **7636** — per-service RPS, p50/p95/p99, error rate
- **Istio Workload Dashboard**: ID **7630** — per-workload view
- **Istio Mesh Dashboard**: ID **7639** — global mesh view
- **Istio Performance Dashboard**: ID **11829** — control plane performance
- **Istio Control Plane**: ID **7645** — istiod health
- **Ztunnel Dashboard**: ID **21306** — ztunnel-specific metrics for ambient

## 3. Microservices app metrics

Your users microservice is FastAPI. If you want app-level metrics beyond what Envoy gives you, add Prometheus instrumentation:

```python
# requirements.txt
prometheus-fastapi-instrumentator

# main.py
from prometheus_fastapi_instrumentator import Instrumentator
Instrumentator().instrument(app).expose(app)
# Now /metrics serves app metrics
```

Then create a PodMonitor pointing to the app's `/metrics` endpoint on its service port. Same pattern for your Node.js services using `prom-client`.

**For the load test specifically**, you probably don't need this — Envoy metrics (via the sidecar) give you RPS, latency, and error rate per service, which is 90% of what you want. Skip app-level instrumentation for now unless you find gaps.

## 4. Tempo tracing dashboard

Tempo doesn't emit dashboards via Prometheus — you query it directly in Grafana's Explore view. But there's a good **service graph + span timing dashboard**:

- **Tempo Operational Dashboard**: ID **17587** — Tempo's own health (ingestion rate, errors)
- **APM Dashboard for Tempo**: the `tempo-distributed` chart or `tempo` chart ships this via the `tempo.metricsGenerator` feature if you enable it

For the "user (2ms) → PG DB (1.3ms)" trace view specifically, that's just the default Tempo Search UI in Grafana Explore — no dashboard needed. You click a trace and see the waterfall. To get **service graph metrics** (topology view + edge latencies in a dashboard), you need to enable Tempo's metrics generator:

```yaml
# In your tempo Helm values
tempo:
  metricsGenerator:
    enabled: true
    remoteWriteUrl: http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/write
  overrides:
    defaults:
      metrics_generator:
        processors: [service-graphs, span-metrics]
```

This generates `traces_service_graph_request_total` and `traces_spanmetrics_latency` in your Prometheus, which the "Tempo APM" dashboard reads. **Note**: this requires Prometheus to have remote-write enabled — set `prometheus.prometheusSpec.enableRemoteWriteReceiver: true` in kube-prometheus-stack values.

## 5. HPA dashboard

For the HPA panel you mentioned, there's a community dashboard:
- **HPA / Horizontal Pod Autoscaler**: ID **17125** — shows current vs desired replicas, utilization, scaling events

Or add a simple custom panel with the PromQL from the runbook.

## 6. k6 test metrics (optional but nice)

To see k6 RPS overlaid with infra metrics, enable Prometheus remote-write in the TestRun:

**First, enable the receiver on Prometheus.** In your kube-prometheus-stack Helm values:

```yaml
prometheus:
  prometheusSpec:
    enableRemoteWriteReceiver: true
```

**Then update your TestRun manifest**:

```yaml
spec:
  runner:
    env:
      - name: K6_PROMETHEUS_RW_SERVER_URL
        value: "http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/write"
      - name: K6_PROMETHEUS_RW_TREND_STATS
        value: "p(50),p(95),p(99),min,max"
      # ... rest of env vars ...
  arguments: --out experimental-prometheus-rw
```

**Dashboard**: **k6 Prometheus dashboard** ID **19665** (official Grafana dashboard for k6 Prometheus remote-write output).

## How to import dashboards

Two approaches:

**Option A: Manual import (quick for now)**
1. Grafana UI → Dashboards → New → Import
2. Paste the ID number (e.g., `20417`)
3. Select your Prometheus datasource
4. Save

**Option B: GitOps via ConfigMap (recommended long-term)**
Grafana has a dashboard sidecar that watches ConfigMaps with a specific label and auto-imports them. Your kube-prometheus-stack's Grafana already runs this sidecar. Create ConfigMaps like:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cnpg-dashboard
  namespace: grafana
  labels:
    grafana_dashboard: "1"  # triggers the sidecar
data:
  cnpg.json: |
    { ... full dashboard JSON ... }
```

You can fetch the JSON from each dashboard's Grafana.com page (download button) and bake them into an ArgoCD Application that syncs ConfigMaps from Git.

## Recommended order for your load-test prep

Do these **before** running the demo:

1. **Add `monitoring.enablePodMonitor: true`** to Postgres Cluster and Pooler — easiest win, unlocks the two most important dashboards
2. **Apply the Istio PodMonitor + istiod ServiceMonitor** from section 2 above
3. **Import dashboards via UI** (fastest path): 20417, 7419, 7636, 7630, 17125
4. Verify in Prometheus targets page that `postgres-cluster`, `postgres-pooler-rw`, `envoy-stats`, `istiod` all show UP
5. **Run the k6 demo** — watch the dashboards populate in real time
6. After the demo succeeds, decide if you want app-level FastAPI metrics and k6 remote-write before the full run

## Quick verification commands

```bash
# After applying the PodMonitors, check Prometheus sees them:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090 &
# Visit http://localhost:9090/service-discovery and http://localhost:9090/targets

# Quick sanity that metrics are being scraped:
curl -s http://localhost:9090/api/v1/query?query=istio_requests_total | jq '.data.result | length'
# Should be > 0 if any traffic is flowing

curl -s http://localhost:9090/api/v1/query?query=cnpg_collector_up | jq '.data.result | length'
# Should be 3 (one per Postgres instance)

curl -s http://localhost:9090/api/v1/query?query=cnpg_pgbouncer_pools | jq '.data.result | length'
# Should be > 0 once traffic hits the pooler
```

Want me to package all these PodMonitor/ServiceMonitor manifests + a dashboards ConfigMap skeleton into the load-testing module, or keep them as a separate "observability-monitors" ArgoCD app?

## Other metrics to monitor

```bash
# CPU throttling rate (% of periods that got throttled)
sum(rate(container_cpu_cfs_throttled_periods_total[2m])) by (pod)
/
sum(rate(container_cpu_cfs_periods_total[2m])) by (pod)

# Total time spent throttled (in seconds)
sum(rate(container_cpu_cfs_throttled_seconds_total[2m])) by (pod)

# Average CPU usage in 10s windows (catches bursts)
rate(container_cpu_usage_seconds_total[10s])

# Retry attempts per second
sum(rate(envoy_cluster_upstream_rq_retry{namespace="users"}[1m]))

# Retries that eventually failed
sum(rate(envoy_cluster_upstream_rq_retry_overflow{namespace="users"}[1m]))

# Successful retries (the value we care about)
sum(rate(envoy_cluster_upstream_rq_retry_success{namespace="users"}[1m]))
```

## How to interpret the `Detailed CPU Usage dashboard` during a load test
When you're watching during the next test, look for these patterns:

**Healthy under load:**

- Throttling rate stays <2%
- Peak CPU stays <80% of limit
- Node CPU stays <70%
- Variance ratio (peak/avg) <2

**Brewing problems:**

- Throttling rate creeping up to 5-15%
- Peak CPU spiking to 90%+ but average stays low
- Node CPU 70-85%
- Variance ratio 3-5

**Active failure:**

- Throttling rate >25%
- Peak CPU pinned at limit
- Node CPU >85% sustained
- Variance ratio >5

The variance ratio is genuinely the most useful single number for "is my dashboard lying to me about CPU usage?" — **if it's >3**, your average dashboards aren't telling the truth.