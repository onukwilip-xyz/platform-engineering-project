# DDoS Simulation Implementation Plan

## Phase 0: Pre-flight checks

Before touching anything, confirm three things:

1. **GKE cluster is on a Premium Tier network** — Cloud Armor's adaptive protection and the global external HTTPS LB only work on Premium Tier. (Should already be the case, but worth verifying with `gcloud compute project-info describe`.)
2. **You have Cloud Armor Standard active** — automatic on any project with an external HTTPS LB, no subscription needed for your test scope. Adaptive Protection works on Standard tier.

---

## Phase 1: Migrate the public Istio Gateway to GKE Gateway class

This is the structural change that makes Cloud Armor possible. Do this in your existing `staging` Terragrunt unit since it modifies existing resources.

### 1.1 Reserve a global external IP

Replace the regional `google_compute_address.public_gateway` with a global one. The global external HTTPS LB requires a global IP.

```hcl
resource "google_compute_global_address" "public_gateway" {
  name         = "public-gateway-ip"
  project      = var.service_project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}
```

**Migration note:** keep the old regional address Terraform-managed in parallel until DNS cutover is complete. Don't delete it in the same apply that creates the new one.

### 1.2 Update the public Gateway resource

Change `gatewayClassName` from your Istio class to `gke-l7-global-external-managed`, and reference the global IP. Your Istio AuthorizationPolicies, retry VirtualServices (with `gateways: [mesh, ...]`), and HTTPRoutes for in-mesh routing all keep working — only the public gateway implementation changes.

```hcl
resource "kubernetes_manifest" "gateway_public" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = kubernetes_namespace.istio_ingress.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = var.public_cluster_issuer_name
      }
    }
    spec = {
      gatewayClassName = "gke-l7-global-external-managed"
      addresses = [{
        type  = "NamedAddress"
        value = google_compute_global_address.public_gateway.name
      }]
      listeners = [{
        name     = "https"
        port     = 443
        protocol = "HTTPS"
        hostname = "*.${var.public_domain}"
        tls = {
          mode = "Terminate"
          certificateRefs = [{ name = "public-gateway-cert", kind = "Secret" }]
        }
        allowedRoutes = { namespaces = { from = "All" } }
      }]
    }
  }
}
```

### 1.3 Bump the Gateway timeout to accommodate sidecar retries

Your VirtualService allows up to 2 attempts × 3s perTry = ~6s of retry budget. Set the GKE Gateway backend timeout to 20s (room for retries plus actual work):

```hcl
resource "kubernetes_manifest" "users_backend_policy" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "GCPBackendPolicy"
    metadata = {
      name      = "users-backend-timeout"
      namespace = "users"
    }
    spec = {
      default = {
        timeoutSec = 20
      }
      targetRef = {
        group = ""
        kind  = "Service"
        name  = "users-microservice-service"
      }
    }
  }
}
```

The Cloud Armor security policy will be attached to this same `GCPBackendPolicy` later — Phase 4.

### 1.4 DNS cutover

Update `*.${var.public_domain}` A records (or wildcard CNAME) to point at the new global address. TTL down to 60s a few hours before cutover, swap, monitor for 24h, then restore TTL. Keep the old regional address allocated but unused during this window in case of rollback.

### 1.5 Verify the migration

Before proceeding to the simulation work, confirm at the migrated public path:

- Existing 40 RPS load test still produces ~99.7–99.8% availability (no regression from the gateway swap).
- TLS cert is still being rotated by cert-manager (check the Secret's age, force a renewal as a smoke test).
- HTTPRoutes still resolve correctly (each microservice's external endpoint responds).

If any of these regresses, fix before moving on. **Do not run the DDoS simulation against a freshly migrated gateway with unverified behavior.**

---

## Phase 2: Cloud Armor security policy (in `staging` module)

Add this to the same Terragrunt unit. Cloud Armor is a perimeter resource — keeping it next to the gateway it protects makes the relationship explicit.

### 2.1 The security policy

```hcl
resource "google_compute_security_policy" "public_gateway" {
  name        = "public-gateway-armor"
  project     = var.service_project_id
  description = "Rate limiting + DDoS protection for public Istio gateway"
  type        = "CLOUD_ARMOR"

  # Priority 1000: Allow GCP health check ranges unconditionally
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
      }
    }
    description = "Allow GCP health check probes"
  }

  # Priority 2000: Per-IP rate-based-ban
  rule {
    action   = "rate_based_ban"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 300
        interval_sec = 60
      }
      ban_threshold {
        count        = 550
        interval_sec = 60
      }
      ban_duration_sec = 120
    }
    description = "Throttle at 300/min per IP, ban at 550/min for 2 minutes"
  }

  # Priority 2147483647 (default): allow everything else
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }

  # Adaptive protection — won't fire at 30-45 RPS, but harmless to enable
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }

  # Logging: full verbosity for the test
  advanced_options_config {
    log_level = "VERBOSE"
  }
}
```

### 2.2 Attach via GCPBackendPolicy

Update the `users_backend_policy` from Phase 1.3 to also reference the security policy:

```hcl
spec = {
  default = {
    timeoutSec = 20
    securityPolicy = google_compute_security_policy.public_gateway.name
  }
  targetRef = { ... }
}
```

### 2.3 Configure log sampling on the LB

The GKE Gateway's auto-provisioned backend service needs logging enabled to see Cloud Armor decisions. This is set on the same `GCPBackendPolicy`:

```hcl
spec = {
  default = {
    timeoutSec     = 20
    securityPolicy = google_compute_security_policy.public_gateway.name
    logging = {
      enabled    = true
      sampleRate = 0.1   # 10% of allows; denies are always 100%
    }
  }
}
```

---

## Phase 3: New Terragrunt module — `ddos-simulation`

Create a new unit under your environment hierarchy: `live/staging/ddos-simulation/terragrunt.hcl`. This isolates the simulation infrastructure from your production-equivalent staging stack and lets you destroy it cleanly after the test.

The module owns: **a new GCP project + a standalone VPC + Shared VPC service-project attachment + 3 instance templates + 3 MIGs + firewall rules.**

### 3.1 Module structure

```
modules/
  ddos-simulation/
    main.tf              # project, VPC, service project attachment
    instance_templates.tf
    migs.tf
    firewalls.tf
    startup_scripts/
      attacker_hostname.sh
      attacker_ip.sh
      baseline.sh
    variables.tf
    outputs.tf
```

### 3.2 The project + standalone VPC

```hcl
resource "google_project" "ddos_sim" {
  name            = "DDoS Simulation"
  project_id      = var.ddos_project_id
  billing_account = var.billing_account
  org_id          = var.org_id
}

resource "google_project_service" "ddos_sim" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
  ])
  project = google_project.ddos_sim.project_id
  service = each.value
}

# Standalone VPC for attack traffic egress
resource "google_compute_network" "attack_vpc" {
  project                 = google_project.ddos_sim.project_id
  name                    = "attack-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.ddos_sim]
}

# Subnet for attack region (e.g., us-central1)
resource "google_compute_subnetwork" "attack_primary" {
  project       = google_project.ddos_sim.project_id
  name          = "attack-subnet-primary"
  network       = google_compute_network.attack_vpc.id
  ip_cidr_range = "10.200.0.0/24"
  region        = var.attack_region
}

# Subnet for baseline region (different region for distinct IP pool)
resource "google_compute_subnetwork" "attack_baseline" {
  project       = google_project.ddos_sim.project_id
  name          = "attack-subnet-baseline"
  network       = google_compute_network.attack_vpc.id
  ip_cidr_range = "10.201.0.0/24"
  region        = var.baseline_region
}
```

### 3.3 Shared VPC service project attachment

```hcl
resource "google_compute_shared_vpc_service_project" "ddos_sim" {
  host_project    = var.shared_vpc_host_project
  service_project = google_project.ddos_sim.project_id
  depends_on      = [google_project_service.ddos_sim]
}

# Grant the attacker project's compute SA the networkUser role on the GKE subnet
# so nic1 can attach to it
resource "google_compute_subnetwork_iam_member" "attacker_network_user" {
  project    = var.shared_vpc_host_project
  region     = var.gke_region
  subnetwork = var.gke_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_project.ddos_sim.number}-compute@developer.gserviceaccount.com"
}
```

### 3.4 Firewall rules

Two sets — one on the standalone VPC (allowing IAP SSH for debugging), one on the Shared VPC host project (allowing nic1 → Prometheus).

```hcl
# Standalone VPC: allow IAP SSH for troubleshooting
resource "google_compute_firewall" "iap_ssh" {
  project = google_project.ddos_sim.project_id
  network = google_compute_network.attack_vpc.name
  name    = "allow-iap-ssh"

  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Standalone VPC: allow VMs egress to internet (default route exists; this is firewall layer)
resource "google_compute_firewall" "egress_internet" {
  project   = google_project.ddos_sim.project_id
  network   = google_compute_network.attack_vpc.name
  name      = "allow-egress-internet"
  direction = "EGRESS"

  destination_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }
}

# Shared VPC host project: allow attacker nic1 → Prometheus (private gateway)
resource "google_compute_firewall" "attacker_metrics_to_prom" {
  project = var.shared_vpc_host_project
  network = var.shared_vpc_network
  name    = "allow-ddos-sim-metrics"

  source_ranges = [
    google_compute_subnetwork.attack_primary.ip_cidr_range,
    google_compute_subnetwork.attack_baseline.ip_cidr_range,
  ]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # Scope to just the gateway IP, not the whole subnet
  destination_ranges = ["${var.private_gateway_ip}/32"]
}
```

### 3.5 The three startup scripts

Each script: install Docker, configure `/etc/hosts`, pull the k6 image, run the test loop. Differences are RPS, target URL, and whether the VM hits hostname or IP.

**`startup_scripts/attacker_hostname.sh`** (used by attacker MIG #1)

```bash
#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/startup.log) 2>&1

# Wait for nic1 to be ready
for i in {1..30}; do
  ip -4 addr show | grep -q "inet 10\." && break
  sleep 1
done

# Read instance metadata
PROM_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/prometheus_ip)
TARGET_HOST=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/target_host)
WRITE_RPS=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/write_rps)
READ_RPS=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/read_rps)
TEST_DURATION=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/test_duration)

# /etc/hosts override for the metrics endpoint (bypass Cloud DNS)
echo "${PROM_IP}  prometheus.internal.pe.onukwilip.xyz" >> /etc/hosts

# Verify routing
ip route get "${PROM_IP}"

# Install Docker
apt-get update
apt-get install -y docker.io
systemctl start docker

# Write the k6 script
mkdir -p /opt/k6
cat > /opt/k6/test.js <<EOF
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    writes: {
      executor: 'constant-arrival-rate',
      rate: ${WRITE_RPS},
      timeUnit: '1s',
      duration: '${TEST_DURATION}',
      preAllocatedVUs: 20,
      maxVUs: 50,
      exec: 'doWrite',
    },
    reads: {
      executor: 'constant-arrival-rate',
      rate: ${READ_RPS},
      timeUnit: '1s',
      duration: '${TEST_DURATION}',
      preAllocatedVUs: 10,
      maxVUs: 20,
      exec: 'doRead',
    },
  },
};

const BASE = 'https://${TARGET_HOST}';

export function doWrite() {
  const res = http.post(\`\${BASE}/users\`,
    JSON.stringify({ email: \`u\${__VU}-\${__ITER}@test.local\`, password: 'x' }),
    { headers: { 'Content-Type': 'application/json', 'Host': '${TARGET_HOST}' },
      tags: { mig: '${MIG_LABEL}', method: 'write' } });
  check(res, { 'status not 5xx': (r) => r.status < 500 });
}

export function doRead() {
  const res = http.get(\`\${BASE}/users/me\`,
    { headers: { 'Host': '${TARGET_HOST}' },
      tags: { mig: '${MIG_LABEL}', method: 'read' } });
  check(res, { 'status not 5xx': (r) => r.status < 500 });
}
EOF

# Run k6 with Prometheus remote-write
docker run --rm \
  --network host \
  -v /opt/k6:/scripts \
  -e K6_PROMETHEUS_RW_SERVER_URL=https://prometheus.internal.pe.onukwilip.xyz/api/v1/write \
  -e K6_PROMETHEUS_RW_PUSH_INTERVAL=5s \
  -e K6_PROMETHEUS_RW_TREND_STATS=p(50),p(95),p(99) \
  -e K6_INSECURE_SKIP_TLS_VERIFY=true \
  grafana/k6:latest run -o experimental-prometheus-rw /scripts/test.js
```

**`startup_scripts/attacker_ip.sh`** — same as above but `TARGET_HOST` is the LB IP. The `Host` header is still set to the FQDN so the HTTPRoute matches; this confirms Cloud Armor protects IP-direct access too.

**`startup_scripts/baseline.sh`** — same structure, lower RPS values via instance metadata.

The instance template injects metadata variables, so one script template per role is enough.

### 3.6 Three instance templates

```hcl
locals {
  # Common metadata baseline
  common_metadata = {
    prometheus_ip = var.private_gateway_ip
    test_duration = "30m"
    enable-oslogin = "TRUE"
  }
}

resource "google_compute_instance_template" "attacker_hostname" {
  project      = google_project.ddos_sim.project_id
  name_prefix  = "attacker-hostname-"
  machine_type = "e2-standard-2"
  region       = var.attack_region

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  # nic0: standalone attack VPC, ephemeral public IP
  network_interface {
    network    = google_compute_network.attack_vpc.id
    subnetwork = google_compute_subnetwork.attack_primary.id
    access_config {} # ephemeral public IP
  }

  # nic1: Shared VPC, no public IP
  network_interface {
    network    = var.shared_vpc_self_link
    subnetwork = var.gke_subnet_self_link
  }

  metadata = merge(local.common_metadata, {
    target_host = "users.${var.public_domain}"
    write_rps   = "7"
    read_rps    = "3"
    mig_label   = "attacker-hostname"
    startup-script = file("${path.module}/startup_scripts/attacker_hostname.sh")
  })

  service_account {
    email  = google_service_account.ddos_runner.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# attacker_ip — same shape, target_host = LB IP
resource "google_compute_instance_template" "attacker_ip" {
  # ... identical structure, metadata.target_host = google_compute_global_address.public_gateway.address
  # ... metadata.mig_label = "attacker-ip"
}

# baseline — different region, lower RPS
resource "google_compute_instance_template" "baseline" {
  region = var.baseline_region
  network_interface {
    network    = google_compute_network.attack_vpc.id
    subnetwork = google_compute_subnetwork.attack_baseline.id
    access_config {}
  }
  network_interface {
    network    = var.shared_vpc_self_link
    subnetwork = var.gke_subnet_self_link
  }
  metadata = merge(local.common_metadata, {
    target_host = "users.${var.public_domain}"
    write_rps   = "2"
    read_rps    = "1"
    mig_label   = "baseline"
  })
  # ...
}
```

### 3.7 Three MIGs

```hcl
resource "google_compute_region_instance_group_manager" "attacker_hostname" {
  project            = google_project.ddos_sim.project_id
  name               = "attacker-hostname-mig"
  region             = var.attack_region
  base_instance_name = "atk-host"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.attacker_hostname.self_link
  }

  # No autoscaler — fixed size
}

resource "google_compute_region_instance_group_manager" "attacker_ip" {
  # target_size = 2, region = var.attack_region
  # template = google_compute_instance_template.attacker_ip.self_link
}

resource "google_compute_region_instance_group_manager" "baseline" {
  # target_size = 4, region = var.baseline_region
  # template = google_compute_instance_template.baseline.self_link
}
```

Total: 2 + 2 + 4 = **8 VMs**, matching the agreed plan.

### 3.8 RPS math — verification

| MIG | VMs | Per VM (write+read) | Total RPS |
|---|---|---|---|
| attacker_hostname | 2 | 7w + 3r = 10 | 20 |
| attacker_ip | 2 | 7w + 3r = 10 | 20 |
| baseline | 4 | 2w + 1r = 3 | 12 |
| **Sum** | **8** | — | **52** |

Attack total: 40 RPS — matches the 40–45 target.
Baseline total: 12 RPS — slightly under the 15–20 you mentioned, but each VM at 3 RPS is comfortably under the 300/min throttle (180/min observed).

If you want closer to the 15–20 baseline, bump to 3w + 1r per baseline VM = 16 RPS total, still safely under threshold (240/min).

---

## Phase 4: Pre-test validation (before scaling MIGs)

Don't scale all MIGs to full size on day one. Run this validation sequence on a single attacker VM first.

### 4.1 Single-VM smoke test

Set `target_size = 1` on the `attacker_hostname` MIG only. SSH in via IAP and run:

```bash
# Public DNS works
dig +short users.public.onukwilip.xyz

# /etc/hosts override is in place
getent hosts prometheus.internal.pe.onukwilip.xyz

# Attack path egresses via nic0 (public IP)
curl -s https://ifconfig.me  # matches nic0 ephemeral IP

# Public FQDN traceroute should show internet hops
sudo traceroute -n users.public.onukwilip.xyz | head -8

# Prometheus IP routes via nic1 automatically (kernel subnet route)
ip route get $(getent hosts prometheus.internal.pe.onukwilip.xyz | awk '{print $1}')

# Prometheus reachable
curl -sk --connect-timeout 5 https://prometheus.internal.pe.onukwilip.xyz/-/healthy

# 30-second smoke test
docker logs $(docker ps -q --filter ancestor=grafana/k6:latest) | tail -50
```

All six should pass before scaling up.

### 4.2 Cloud Armor preview mode

Before the real test, set the rate-limit rule to `preview = true`. This logs what *would* be blocked without actually blocking. Run a 5-minute preview with attackers at 1 VM each, confirm the logs show the expected DENY decisions, then flip preview off.

```hcl
rule {
  action   = "rate_based_ban"
  priority = 2000
  preview  = true   # ← set to false for real test
  ...
}
```

---

## Phase 5: Run the simulation

### 5.1 Pre-test setup (T-30 minutes)

- Open three monitoring views: Grafana k6 dashboard, Cloud Logging filtered to Cloud Armor decisions, Cloud Monitoring → Cloud Armor policy view.
- Pre-write the Cloud Logging queries:
  ```
  resource.type="http_load_balancer"
  jsonPayload.enforcedSecurityPolicy.name="public-gateway-armor"
  jsonPayload.enforcedSecurityPolicy.outcome="DENY"
  ```
- Confirm GKE pod CPU baseline in Prometheus (so you can compare during attack).
- Have the kill switch ready: `terraform apply -var="ddos_attacker_target_size=0"` to scale all MIGs to 0 instantly.

### 5.2 Test execution

- T+0:00 — Scale all 3 MIGs to target sizes via Terraform.
- T+0:00 to T+0:05 — Watch first 5 minutes carefully. Confirm:
  - k6 dashboard shows attackers at ~10 RPS and baseline at ~3 RPS.
  - Cloud Armor logs show first DENY decisions appearing ~30s after start.
  - Backend pod CPU stays under previous load test ceiling.
- T+0:05 to T+0:25 — Steady state. Periodically refresh dashboards.
- T+0:25 to T+0:30 — Wind-down period. Watch for ban expiries.
- T+0:30 — Scale MIGs to 0.

### 5.3 Post-test analysis

Pull metrics from k6 (Prometheus) and Cloud Armor (Cloud Logging exported to BigQuery for easier aggregation):

| Metric | Target | Source |
|---|---|---|
| Baseline availability | ≥ 99.99% | k6 metrics filtered to `mig="baseline"`, `http_req_failed` rate |
| Attack block rate | ≥ 95% over full window | Cloud Armor `outcome=DENY` count / total attacker request count |
| Backend pod p99 CPU | ≤ previous load test saturation point | Prometheus `container_cpu_usage_seconds_total` |
| Baseline p99 latency | ≤ 2× pre-attack baseline | k6 `http_req_duration{p(99)}` filtered to baseline MIG |

---

## Phase 6: Teardown

```bash
cd live/staging/ddos-simulation/
terragrunt destroy
```

The `ddos-simulation` module owns the entire blast radius — no orphaned resources, no leftover firewall holes in the Shared VPC. The Cloud Armor policy stays in `staging` because it's now part of your production-equivalent perimeter.

---

## Summary of artifacts

By the end of this:

- ✅ Public Istio gateway migrated to GKE Gateway class with global external HTTPS LB
- ✅ Cloud Armor security policy attached via `GCPBackendPolicy`, with rate-limit thresholds 300/550/120s
- ✅ New isolated `ddos-simulation` Terragrunt module containing project + standalone VPC + Shared VPC service-project attachment + 3 instance templates + 3 MIGs + firewall rules
- ✅ k6 + Prometheus remote-write dual-NIC architecture with `/etc/hosts` for the metrics endpoint
- ✅ Validation sequence to run before full-scale test
- ✅ Documented pass/fail criteria and post-test analysis queries
- ✅ Clean teardown path

**Open questions for you to decide before implementation:**

1. **TLS verification for Prometheus push** — skip via `K6_INSECURE_SKIP_TLS_VERIFY=true` (simpler) or bake the internal CA into the VM (cleaner). I'd go skip-verify for a one-off test.
2. **Baseline RPS** — keep at 2w/1r = 3 RPS per VM (12 total) or bump to 3w/1r = 4 RPS per VM (16 total) for closer alignment with the 15–20 target.
3. **Attack region pair** — which two regions? Defaults `us-central1` for attack, `europe-west1` for baseline give clean IP separation.
4. **Test duration** — 30 minutes confirmed, or want to shorten to 20 if you're paying close attention?