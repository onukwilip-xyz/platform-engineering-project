## Concrete plan for your situation

Given credit timeline, I'd suggest **Approach 2 (k6 Operator)** with this phased execution:

### Phase 1: Setup (30 min)
1. Install the k6 Operator via its Helm chart (or plain manifests) into a dedicated `load-testing` namespace. Label the namespace `istio.io/dataplane-mode: ambient` so runners get transparent mTLS when hitting internal endpoints.
2. Confirm access to the Users microservice via its internal service DNS: `users-microservice-service.users.svc.cluster.local`.
3. Write two k6 scripts in a ConfigMap:
   - `write-heavy.js`: 70% POST `/users` (create), 30% GET `/users/:id` (read)
   - `read-heavy.js`: 10% POST, 90% GET (mimics real e-commerce traffic)

### Phase 2: Baseline (15 min)
Run a small test first: `parallelism: 2`, 500 VUs, 2 minutes. Confirm:
- Requests land on the Users service
- Istio sidecar metrics show traffic in Prometheus
- Traces appear in Tempo
- No immediate failures

### Phase 3: Scale to target (main test, 1 hr)
A 2M req/hr run over 1 hour:
- `parallelism: 6` (six runner pods, six source IPs)
- Each pod drives ~100 RPS → 600 RPS total → 2.16M req/hr
- Duration: 60 minutes sustained
- Mix: 2 pods running write-heavy, 4 pods running read-heavy (realistic 33/67 split)

### Phase 4: Observe autoscaling behavior
Watch in Grafana:
- Users microservice HPA events (you said you're configuring one — CPU/memory scale-out)
- PGBouncer HPA (pooler connection count, pod replicas)
- CNPG Postgres cluster VPA (resource recommendations and restarts)
- Istio request metrics (p50/p95/p99, error rate)
- Logs in Loki for error patterns
- Traces in Tempo for slow requests

### Phase 5: Stress to breaking point
Gradually increase `parallelism` until something breaks. Common breaking points you'll find:
- **PGBouncer connection limits** — likely hit first; this validates your HPA is working
- **Postgres CPU saturation** — VPA should bump resources, but VPA restarts pods (check for gaps in availability)
- **Users microservice CPU or connection pool** — HPA should scale out
- **Istio sidecar CPU** — if sidecars saturate before the app, bump `sidecar.istio.io/proxyCPULimit`

## Key script patterns for your test

A few things to build into your k6 script:

- **Unique user generation**: each POST must create a unique user → use `__VU` (virtual user ID) and `__ITER` (iteration) as seed: `email: \`user-{__VU}-{__ITER}@test.com\``. Without this, you'll hit uniqueness constraints and skew error metrics.
- **Capture IDs between requests**: after POST returns 201, grab the user ID from the response body and use it in a subsequent GET to simulate real user flow.
- **Think time**: add `sleep(Math.random() * 2)` between requests — constant hammering is unrealistic and doesn't test connection-pool reuse patterns.
- **Thresholds**: define pass/fail in the script (e.g., `http_req_duration: ['p(95)<500']`) so the test objectively passes or fails.
- **Scenarios for traffic mix**: k6 lets you run multiple scenarios in parallel (`ramping-vus` for write-heavy, `constant-arrival-rate` for read-heavy), so one run exercises both patterns.

## One caveat: cleanup before load testing

Since you've got credits expiring, verify these aren't silently eating your budget during the test:
- **GMP** is still ingesting (your earlier config still has `managed_prometheus.enabled = true`) → every metric sample costs money. Disable before the test or you'll pay twice (self-hosted Prometheus AND GMP).
- **Cloud Logging**: GKE sends logs there by default. A 1-hour 2M req/hr test with Istio access logs can generate tens of GB → real money. Check your GKE logging config (`logging_config` block) and consider scoping to SYSTEM only.
- **GCS egress**: traffic stays in-cluster so this shouldn't matter, but double-check Loki/Tempo aren't cross-region.

## My recommendation

**Go with k6 Operator.** It's the most widely adopted open-source approach for Kubernetes-native distributed load testing, officially maintained by Grafana, declarative, and integrates with the observability stack you just built. Your stack (JS/TypeScript microservices) makes the JavaScript test scripts natural to write.