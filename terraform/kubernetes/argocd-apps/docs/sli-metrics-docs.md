# SLO Burn Rate — Reference Guide

Platform: `onukwilip.xyz` GKE stack  
SLO operator: Sloth v0.16.0  
Alert engine: Grafana v12.4.3 + kube-prometheus-stack

---

## Core Concepts

### Error Budget

The **error budget** is the maximum fraction of requests that are allowed to fail over the SLO window (30 days), derived directly from the SLO objective:

```
error_budget = 1 - SLO_objective
```

| Service / SLO | Objective | Error Budget |
|---|---|---|
| users-microservice / availability | 99.5% | 0.005 (0.5%) |
| users-microservice / latency <500ms | 99.0% | 0.010 (1.0%) |
| store-ui / availability | 99.0% | 0.010 (1.0%) |
| store-ui / latency <1000ms | 99.0% | 0.010 (1.0%) |
| postgres-cluster / availability | 99.9% | 0.001 (0.1%) |

---

### Error Ratio (SLI)

The **error ratio** is what Sloth's recording rules measure. It is a number between 0 and 1:

```
error_ratio = (total_requests - good_requests) / total_requests
```

- `0.0` = perfect, zero failures
- `0.5` = 50% of requests failed
- `1.0` = 100% of requests failed (complete outage)

Sloth generates one recording rule per time window:

```
slo:sli_error:ratio_rate5m   ← 5-minute rolling window
slo:sli_error:ratio_rate30m  ← 30-minute rolling window
slo:sli_error:ratio_rate1h   ← 1-hour rolling window
slo:sli_error:ratio_rate2h
slo:sli_error:ratio_rate6h
slo:sli_error:ratio_rate1d
slo:sli_error:ratio_rate3d
slo:sli_error:ratio_rate30d  ← used for period burn rate
```

---

### Burn Rate

The **burn rate** is how fast you are consuming the error budget, relative to the 1× baseline:

```
burn_rate = error_ratio / error_budget
```

| Burn rate | Meaning |
|---|---|
| 1× | Consuming budget at exactly the right pace — 30-day budget exhausts in exactly 30 days |
| <1× | Under-burning — budget will last longer than 30 days |
| >1× | Over-burning — budget exhausts before 30 days |
| 14.4× | Page alert threshold — budget exhausts in ~2 days |
| 6× | Second page pair / ticket threshold — budget exhausts in ~5 days |

#### Burn Rate Examples (users-microservice, budget=0.005)

| Error ratio (SLI value) | Burn rate | Budget exhausts in |
|---|---|---|
| 0.005 | 1× | 30 days |
| 0.0720 | 14.4× | ~2 days |
| 0.0300 | 6× | ~5 days |
| 0.5000 | 100× | ~7.2 hours |
| 0.8157 | 163.1× | ~4.4 hours |
| 1.0000 | 200× | ~3.6 hours |

---

### Days to Budget Exhaustion

```
days_to_exhaustion = 30 / burn_rate
```

Or equivalently:

```
days_to_exhaustion = 30 × error_budget / error_ratio
```

#### Quick reference

| Burn rate | Days remaining |
|---|---|
| 1× | 30.0 days |
| 2× | 15.0 days |
| 6× | 5.0 days |
| 14.4× | 2.08 days (~50 hours) |
| 36× | 20 hours |
| 100× | 7.2 hours |
| 200× | 3.6 hours |

---

## Multi-Window Alert Logic

Sloth and the Grafana alert rules implement the **Google SRE multi-window multi-burn-rate** alerting pattern. Each alert checks two time windows simultaneously to balance sensitivity and false-positive resistance.

### Why two windows?

- **Short window** (5m, 30m) — detects the current rate of burning. Responds quickly but can spike temporarily.
- **Long window** (1h, 6h) — confirms the burn has been sustained. Filters out short spikes.

An alert only fires when **both** windows exceed the threshold simultaneously. This ensures:
- A 2-minute spike doesn't page you
- A real sustained outage does page you within minutes

### Alert pairs

Each alert consists of **two AND-pairs combined with OR**, mapped to `+` in Grafana's math expression to avoid label collisions:

```
E = (pair1_short > threshold && pair1_long > threshold)
  + (pair2_short > threshold && pair2_long > threshold)

F = E > 0   ← fires if either pair (or both) is true
```

#### Page alert (fast burn — act immediately)

| Pair | Long window | Short window | Threshold | Meaning |
|---|---|---|---|---|
| Pair 1 | 1h | 5m | `14.4 × budget` | Budget exhausts in ~2 days |
| Pair 2 | 6h | 30m | `6 × budget` | Budget exhausts in ~5 days |

`for: 2m` — must be sustained for 2 minutes before firing.

#### Ticket alert (slow burn — investigate soon)

| Pair | Long window | Short window | Threshold | Meaning |
|---|---|---|---|---|
| Pair 1 | 1d | 2h | `3 × budget` | Budget exhausts in ~10 days |
| Pair 2 | 3d | 6h | `1 × budget` | Budget exhausts in 30 days |

`for: 15m` — must be sustained for 15 minutes before firing.

### Threshold values by service

#### users-microservice availability (budget=0.005)

| Alert | Pair | Threshold expression | Threshold value |
|---|---|---|---|
| Page | 1h + 5m | 14.4 × 0.005 | **0.0720** |
| Page | 6h + 30m | 6 × 0.005 | **0.0300** |
| Ticket | 1d + 2h | 3 × 0.005 | **0.0150** |
| Ticket | 3d + 6h | 1 × 0.005 | **0.0050** |

#### users-microservice latency / store-ui availability / store-ui latency (budget=0.010)

| Alert | Pair | Threshold expression | Threshold value |
|---|---|---|---|
| Page | 1h + 5m | 14.4 × 0.010 | **0.1440** |
| Page | 6h + 30m | 6 × 0.010 | **0.0600** |
| Ticket | 1d + 2h | 3 × 0.010 | **0.0300** |
| Ticket | 3d + 6h | 1 × 0.010 | **0.0100** |

#### postgres-cluster availability (budget=0.001)

| Alert | Pair | Threshold expression | Threshold value |
|---|---|---|---|
| Page | 1h + 5m | 14.4 × 0.001 | **0.01440** |
| Page | 6h + 30m | 6 × 0.001 | **0.00600** |
| Ticket | 1d + 2h | 3 × 0.001 | **0.00300** |
| Ticket | 3d + 6h | 1 × 0.001 | **0.00100** |

---

## Reading a Firing Alert

Example alert received during load test:

```
CRITICAL: SLO: Users Service Availability Fast Burn
Status: FIRING
Description: Pair1 — 1h: 0.8157, 5m: 1.0000.
             Pair2 — 6h: 0.5837, 30m: 0.9237.
```

Step-by-step interpretation (budget=0.005):

| Step | Calculation | Result |
|---|---|---|
| 5m error ratio | — | 1.0000 (100% failures) |
| 5m burn rate | 1.0000 ÷ 0.005 | **200×** |
| 5m days to exhaustion | 30 ÷ 200 | **3.6 hours** |
| 1h error ratio | — | 0.8157 (81.6% failures) |
| 1h burn rate | 0.8157 ÷ 0.005 | **163.1×** |
| 1h days to exhaustion | 30 ÷ 163.1 | **4.4 hours** |
| 6h error ratio | — | 0.5837 (58.4% failures) |
| 6h burn rate | 0.5837 ÷ 0.005 | **116.7×** |
| 30m error ratio | — | 0.9237 (92.4% failures) |
| 30m burn rate | 0.9237 ÷ 0.005 | **184.7×** |
| Pair 1 fires? | 163.1 > 14.4 AND 200 > 14.4 | **YES** |
| Pair 2 fires? | 116.7 > 6 AND 184.7 > 6 | **YES** |
| E expression | 1 + 1 = 2 | **2 > 0 → ALERT** |

---

## Key Prometheus Recording Rules

Sloth also generates meta recording rules useful for dashboards:

| Recording rule | Value | Meaning |
|---|---|---|
| `slo:objective:ratio` | e.g. 0.995 | The SLO target |
| `slo:error_budget:ratio` | e.g. 0.005 | 1 - objective |
| `slo:current_burn_rate:ratio` | real-time | Current burn rate (5m SLI ÷ budget) |
| `slo:period_burn_rate:ratio` | real-time | 30d average burn rate ÷ budget |
| `slo:period_error_budget_remaining:ratio` | 0–1 | Fraction of 30-day budget remaining |
| `slo:time_period:days` | 30 | SLO window in days |

Query current budget remaining:
```promql
slo:period_error_budget_remaining:ratio{sloth_service="users-microservice"}
```

Query current burn rate (as a multiple):
```promql
slo:current_burn_rate:ratio{sloth_service="users-microservice"}
  / on(sloth_id, sloth_slo, sloth_service)
slo:error_budget:ratio{sloth_service="users-microservice"}
```

---

## NaN and No-Data Handling

When there is **zero traffic**, the recording rule computes `0/0 = NaN`. The PromQL query in each alert ref uses:

```promql
max without(sloth_window) (slo:sli_error:ratio_rateXX{...}) >= 0
```

`NaN >= 0` is **false** in PromQL (NaN fails all comparisons per IEEE 754), so the series is dropped → Grafana sees no data → `noDataState: OK` → alert stays Normal. No false positives from idle services.

---

## References

- [Google SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Sloth documentation](https://sloth.dev/introduction/)
- [Prometheus comparison operators](https://prometheus.io/docs/prometheus/latest/querying/operators/#comparison-binary-operators)
- [Multi-window multi-burn-rate alerts (original paper)](https://sre.google/workbook/alerting-on-slos/#6-multiwindow-multi-burn-rate-alerts)