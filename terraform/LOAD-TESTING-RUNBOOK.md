# Load Testing Runbook — Users Microservice

## 1. Install the k6 Operator

```bash
# Helm install into its own namespace (operator manages k6 CRDs cluster-wide)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install k6-operator grafana/k6-operator \
  --namespace k6-operator-system \
  --create-namespace
```

Verify:
```bash
kubectl get pods -n k6-operator-system
kubectl get crd | grep k6.io
# Expect: testruns.k6.io, privateloadzones.k6.io
```

## 2. Apply namespace + load the script as a ConfigMap

```bash
kubectl apply -f manifests/01-namespace.yaml

# Load the script from disk — always do this after editing the script
kubectl create configmap k6-write-heavy \
  --from-file=write-heavy.js=scripts/write-heavy.js \
  -n load-testing \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 3. Run the DEMO first (this is your "dry run")

**Never skip this step.** The demo validates the full pipeline before you
commit to the 1-hour run.

```bash
kubectl apply -f manifests/03-testrun-demo.yaml
```

### What to watch during the 2-minute demo

Open **4 terminal windows** simultaneously:

**Terminal 1 — k6 runner pods**
```bash
kubectl get pods -n load-testing -w
# Expect: 2 runner pods go Pending → Running → Completed
# Also: k6-demo-write-heavy-starter and -initializer pods briefly
```

**Terminal 2 — k6 logs (live RPS + errors)**
```bash
# After runners are Running:
kubectl logs -n load-testing -l k6_cr=k6-demo-write-heavy -f --max-log-requests=10
# Look for: "default" scenario running, request counts climbing
```

**Terminal 3 — Users microservice**
```bash
kubectl get pods -n users -w
# Should see new replicas appear if HPA triggers (may not at this low load)

# In another pane:
kubectl top pods -n users
# Watch CPU/memory grow
```

**Terminal 4 — Postgres + pooler**
```bash
kubectl top pods -n postgres
kubectl get hpa -n postgres -w
# Watch postgres-pooler-rw-hpa CPU % — it should rise above idle
```

### Demo validation checklist

After the demo completes (~2 min), verify **each** of these:

- [ ] **k6 runner pods ran to completion** (`Completed` status, no `Error`)
- [ ] **k6 summary shows successful writes** — check logs for the summary box at the end, `Users created` should be > 0 and error rate < 2%
- [ ] **Istio metrics in Prometheus** — open Grafana, query:
    ```
    sum(rate(istio_requests_total{destination_service_namespace="users"}[1m])) by (response_code)
    ```
    Should show a bump during the test window.
- [ ] **Traces in Tempo** — Grafana → Explore → Tempo datasource → Search
    service name `users-microservice` (or whatever your app reports as).
    Click a trace, confirm you see: gateway → sidecar → app → Postgres call.
- [ ] **Logs in Loki** — Grafana → Explore → Loki → query:
    ```
    {namespace="users"} |= "POST"
    ```
    Should show request logs from the users service.
- [ ] **No unexpected 5xx** — in k6 log summary, `http_req_failed` should be
    close to 0. If it's > 5%, STOP and debug before the full run.

**If any checkbox fails, do NOT run the full test.** See Debugging section.

## 4. Run the full 10-pod test

Only after the demo passes all checks:

```bash
# Clean up the demo TestRun first — k6-operator keeps completed jobs around
kubectl delete testrun k6-demo-write-heavy -n load-testing

# Launch the full run
kubectl apply -f manifests/04-testrun-full.yaml
```

## 5. Monitoring during the full run

### Grafana dashboards to have open (in tabs)

1. **Istio Service Dashboard** — filter by `destination_workload=users-microservice-deployment`
   - Watch: p50/p95/p99 latency, RPS, success rate
2. **Kubernetes / Compute Resources / Namespace (Pods)** — namespace = users
   - Watch: pod CPU, memory, network
3. **Kubernetes / Compute Resources / Namespace (Pods)** — namespace = postgres
   - Same metrics for the DB cluster + pooler
4. **Custom panel** — HPA status:
    ```promql
    kube_horizontalpodautoscaler_status_current_replicas{namespace=~"users|postgres"}
    kube_horizontalpodautoscaler_status_desired_replicas{namespace=~"users|postgres"}
    ```
5. **Loki** — live tail of errors:
    ```
    {namespace=~"users|postgres"} |~ "(?i)error|panic|fatal"
    ```

### Useful PromQL queries

```promql
# Request rate by response code
sum(rate(istio_requests_total{destination_service_namespace="users"}[1m])) by (response_code)

# p95 latency to users service
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket{destination_service_namespace="users"}[1m])) by (le)
)

# PGBouncer active connections (if exporter is configured)
pgbouncer_pools_server_active_connections

# Postgres connection count
pg_stat_database_numbackends{datname!~"template.*|postgres"}

# CNPG cluster replica lag
cnpg_pg_stat_replication_lag_seconds
```

## 6. Debugging — what to check if things go wrong

### Symptom: k6 reports high error rate (> 5%)

**First check: is it HTTP-level or transport-level?**
```bash
kubectl logs -n load-testing -l k6_cr=k6-demo-write-heavy | grep -E "status=|dial|timeout"
```

| Error pattern | Likely cause | Fix |
|---|---|---|
| `status=503` | Upstream pod unavailable, likely during HPA scale-up | Wait, or pre-warm by setting higher `minReplicas` |
| `status=500` | App error — bug, DB connection issue | Check users pod logs in Loki |
| `status=429` | Rate-limiting (Istio or app-level) | Check Istio `AuthorizationPolicy` or app rate limiter |
| `dial tcp: i/o timeout` | Network/DNS issue, or destination pod terminating | Check `kube-dns`, check pod restart count |
| `EOF` / `connection reset` | Sidecar or upstream crashing under load | Check OOMKilled events, bump sidecar resources |
| `x509: certificate signed by unknown authority` | Gateway TLS cert not trusted by runner | Make sure your internal CA is trusted; use `insecureSkipTLSVerify` in k6 if acceptable for test |

### Symptom: Users microservice CPU-starved

```bash
kubectl top pods -n users
kubectl get hpa -n users
kubectl describe hpa -n users users-microservice-hpa
```

- If `Current replicas = Max replicas`, the HPA ceiling is your bottleneck —
  raise `maxReplicas`.
- If `Current replicas < Desired replicas`, the scaler is active but the
  scheduler can't place new pods — check node capacity (`kubectl top nodes`).
- If CPU utilization is high but HPA isn't scaling, check `ContainerResource`
  metric config — the HPA might be averaging app + istio-proxy CPU.

### Symptom: PGBouncer saturated

```bash
kubectl top pods -n postgres
kubectl get hpa -n postgres postgres-pooler-rw-hpa
kubectl exec -n postgres deploy/postgres-pooler-rw -- \
  psql -U pgbouncer -p 5432 pgbouncer -c "SHOW POOLS;"
```

Look at `cl_waiting` (clients queued waiting for a server connection).
If it's consistently > 0, increase `default_pool_size` in CNPG pooler config.

### Symptom: Postgres CPU at 100%, writes slow

```bash
kubectl exec -n postgres postgres-cluster-1 -- \
  psql -U postgres -c "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

Common causes under write load:
- **No index on `email` column** → unique constraint checks do full scans
- **WAL writes to slow disk** → use `premium-rwo` StorageClass for CNPG PVCs
- **fsync bottleneck** → tune `synchronous_commit` if durability requirements allow
- **VPA restarting pods** → check `kubectl describe vpa` — if it's applying
  new requests, pods restart and you'll see connection drops. Consider
  setting `updateMode: "Off"` on VPA during load test, observe recommendations
  only, and apply manually after.

### Symptom: Istio sidecar is the bottleneck

Sidecar saturation shows up as:
- App container CPU normal, but request latency still high
- `istio-proxy` container at CPU limit in `kubectl top pods`

Fix with annotations on the users deployment:
```yaml
metadata:
  annotations:
    sidecar.istio.io/proxyCPU: "500m"
    sidecar.istio.io/proxyMemory: "512Mi"
    sidecar.istio.io/proxyCPULimit: "2000m"
    sidecar.istio.io/proxyMemoryLimit: "1Gi"
```

### Symptom: traces missing in Tempo

- Check OTel collector address on istiod — must be reachable from sidecar
- Sampling rate — your istiod is at 1% (`sampling = 1`). For load test
  debugging, temporarily bump via Telemetry resource:
  ```yaml
  apiVersion: telemetry.istio.io/v1
  kind: Telemetry
  metadata:
    name: debug-full-sampling
    namespace: users
  spec:
    tracing:
    - randomSamplingPercentage: 100
  ```
- Verify Tempo ingestion with `kubectl logs -n tracing tempo-0 | grep -i ingest`

### Symptom: Grafana showing no data during test

- Prometheus scrape: `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090` → check Status > Targets
- Cardinality explosion: load tests create high-cardinality labels. If
  Prometheus is OOM'd, check `kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0`
- Loki rate-limiting: if log volume spikes, Loki may drop samples. Check
  `kubectl logs -n logging loki-0 | grep -i "rate limit"`

## 7. Cleanup after the run

```bash
# Delete the TestRun (this also cleans up the Jobs it created)
kubectl delete testrun k6-full-write-heavy -n load-testing

# Delete the created test users from the database (they have identifiable emails)
kubectl exec -n postgres postgres-cluster-1 -- \
  psql -U postgres -d <your-db-name> \
  -c "DELETE FROM users WHERE email LIKE 'loadtest-%@example.com';"
```

## 8. Things to do BEFORE the full test (cost & stability)

- [ ] Disable GMP: set `managed_prometheus.enabled = false` in GKE config,
      apply with Terraform. Every sample you ingest costs money.
- [ ] Scope GKE logging: in `logging_config`, keep only `SYSTEM_COMPONENTS`.
      Drop `WORKLOADS` to avoid double-paying for logs (you have Loki).
- [ ] Pre-warm replicas: set `minReplicas` on users HPA to 2–3 so you don't
      get cold-start 503s in the first 30 seconds of the test.
- [ ] Confirm VPA mode: if your CNPG VPA is `updateMode: Auto`, it will restart
      pods mid-test. Consider `Initial` or `Off` during the test window.
- [ ] Backup idea: snapshot the Postgres cluster before you hammer it.
      CNPG supports scheduled backups via `Backup` CR.
- [ ] Check node pool capacity: 10 k6 runner pods + scaled microservices +
      scaled pooler will stress the node count. Verify autoscaler is enabled
      and max node count is high enough (`gcloud container clusters describe`).

## 9. Suggested progression (don't skip steps)

| Phase | parallelism | WRITE_RATE | READ_RATE | Duration | Approx total RPS |
|-------|-------------|------------|-----------|----------|------------------|
| Demo  | 2           | 5          | 2         | 2m       | 14               |
| Ramp 1| 4           | 10         | 5         | 5m       | 60               |
| Ramp 2| 6           | 15         | 10        | 10m      | 150              |
| Full  | 10          | 25         | 15        | 1h       | 400              |
| Stress| 10          | 50         | 30        | 30m      | 800              |
| Break | 15+         | 100+       | 50+       | until breaks | variable    |

Record observations (HPA replica count, p95 latency, error rate) at each
phase — you'll use this to write up capacity findings.