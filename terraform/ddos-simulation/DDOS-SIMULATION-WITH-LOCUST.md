# DDOS SIMULATION WITH LOCUST

> **Supplements:** the original DDoS simulation plan (Phases 0–6).
> **Replaces:** Phase 3 (the `ddos-simulation` Terragrunt module) and the k6-related parts of Phase 5.
> **Unchanged:** Phase 1 (GKE Gateway migration), Phase 2 (Cloud Armor security policy), Phase 4 (validation sequence), and the Cloud Armor decisions captured in Phases 0–2 + 5.

---

## Why this addendum exists

The original plan baked k6 directly into MIG VM startup scripts, meaning tests started the moment MIGs were created and could only be stopped by deleting the VMs. This addendum introduces a control-plane architecture using Locust master/worker, giving you live start/stop control of three independent test profiles from your laptop via the NetBird VPN.

It also drops Locust's metrics integration with Prometheus — relying on the Locust web UI for live observation and CSV export for post-test analysis — which simplifies the worker VMs to single-NIC.

## What changes vs. the original plan

| Original | Updated |
|---|---|
| 8 worker VMs (k6, 4+2+2) | 6 VMs total: 1 master + 5 workers (2+2+1) |
| Workers run k6 immediately on boot | Workers run Locust as systemd, idle until master starts test |
| No control plane | 1 master VM running 3 Locust masters on different ports |
| 7 writes + 3 reads per VM | 100% writes with `uuid.uuid4()` emails |
| Workers dual-NIC for metrics push | Workers single-NIC (attacker VPC only) |
| Master VM not present | Master VM dual-NIC: attacker VPC (workers) + Shared VPC (NetBird access) |
| k6 metrics → Prometheus remote-write | Locust web UI live + `--csv` export post-test |
| Multi-region baseline (k6 plan) | Single region (matches attackers); per-IP isolation via distinct ephemeral IPs |

## RPS targets

| MIG | VMs | Users/VM | RPS/VM | RPS/min/VM | Total RPS |
|---|---|---|---|---|---|
| attacker-hostname | 2 | 10 | 10 | 600 | 20 |
| attacker-ip | 2 | 10 | 10 | 600 | 20 |
| baseline | 1 | 4 | 4 | 240 | 4 |

Cloud Armor thresholds unchanged from the original plan: throttle at 300/min, ban at 550/min, ban duration 120s.

- Attack VMs at 600/min trip both thresholds within ~55s → ban → cycle.
- Baseline VM at 240/min stays 20% under throttle.

## VM quota math

| Resource | Count | vCPU | Total |
|---|---|---|---|
| Master VM | 1 | 2 | 2 |
| attacker-hostname MIG | 2 | 2 | 4 |
| attacker-ip MIG | 2 | 2 | 4 |
| baseline MIG | 1 | 2 | 2 |
| **Total** | **6** | — | **12** ✅ at quota ceiling |

Set MIG `update_policy.max_surge = 0` to avoid quota collisions during template updates.

## Architecture diagram

```
Your laptop ──NetBird──> Master nic1 (Shared VPC GKE subnet)
                              │ [Locust web UIs :8089, :8090, :8091]
                              │
                         Master VM
                              │
                         Master nic0 (attacker VPC)
                              │ [Locust master ports :5557, :5558, :5559]
                              ▼
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       attacker-hostname  attacker-ip      baseline
       MIG (2 VMs)        MIG (2 VMs)      MIG (1 VM)
       single-NIC         single-NIC       single-NIC
              │               │               │
              └───────────────┼───────────────┘
                              ▼
                     Public internet (egress via ephemeral public IPs)
                              ▼
                     Cloud Armor edge → GKE Gateway → backends
```

## Phase 3-bis: The `ddos-simulation` Terragrunt module

New module under `terraform/ddos-simulation/`. Owns project, VPC, Shared VPC service-project attachment (for master only), master VM, 3 instance templates, 3 MIGs, firewall rules, DNS record.

### 3-bis.1 Module structure

```
modules/
  ddos-simulation/
    main.tf                              # project, VPC, subnets, Shared VPC service-project
    master.tf                            # master VM, dual-NIC, systemd units
    workers.tf                           # 3 instance templates + 3 MIGs
    firewalls.tf                         # attacker VPC + Shared VPC rules
    dns.tf                               # ddos-plane DNS record
    locust/
      locustfile_attacker_hostname.py
      locustfile_attacker_ip.py
      locustfile_baseline.py
    startup_scripts/
      master.sh
      worker.sh
    systemd/
      locust-master-attacker-hostname.service
      locust-master-attacker-ip.service
      locust-master-baseline.service
      locust-worker.service
    variables.tf
    outputs.tf
```

### 3-bis.2 Project + standalone VPC

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

resource "google_compute_network" "attack_vpc" {
  project                 = google_project.ddos_sim.project_id
  name                    = "attack-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.ddos_sim]
}

resource "google_compute_subnetwork" "attack_primary" {
  project       = google_project.ddos_sim.project_id
  name          = "attack-subnet"
  network       = google_compute_network.attack_vpc.id
  ip_cidr_range = "10.200.0.0/24"
  region        = var.attack_region
}
```

### 3-bis.3 Shared VPC service-project attachment (master only)

The master VM needs nic1 on the Shared VPC GKE subnet. Workers do not.

```hcl
resource "google_compute_shared_vpc_service_project" "ddos_sim" {
  host_project    = var.shared_vpc_host_project
  service_project = google_project.ddos_sim.project_id
  depends_on      = [google_project_service.ddos_sim]
}

# Grant compute SA networkUser on the GKE subnet (host project side)
resource "google_compute_subnetwork_iam_member" "master_network_user" {
  project    = var.shared_vpc_host_project
  region     = var.gke_region
  subnetwork = var.gke_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_project.ddos_sim.number}-compute@developer.gserviceaccount.com"
}
```

### 3-bis.4 Master VM

```hcl
resource "google_service_account" "master" {
  project      = google_project.ddos_sim.project_id
  account_id   = "ddos-master"
  display_name = "DDoS simulation master VM"
}

resource "google_storage_bucket_iam_member" "master_locust_read" {
  bucket = var.locustfiles_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.master.email}"
}

resource "google_compute_instance" "master" {
  project      = google_project.ddos_sim.project_id
  name         = "ddos-master"
  machine_type = "e2-standard-2"   # 2 vCPU
  zone         = var.attack_zone

  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }

  # nic0: attacker VPC (workers connect here on internal IP)
  network_interface {
    network    = google_compute_network.attack_vpc.id
    subnetwork = google_compute_subnetwork.attack_primary.id
  }

  # nic1: Shared VPC GKE subnet (NetBird access from laptop)
  network_interface {
    network    = var.shared_vpc_self_link
    subnetwork = var.gke_subnet_self_link
  }

  metadata = {
    enable-oslogin     = "TRUE"
    locustfiles_bucket = var.locustfiles_bucket
    startup-script     = file("${path.module}/startup_scripts/master.sh")
  }

  service_account {
    email  = google_service_account.master.email
    scopes = ["cloud-platform"]
  }

  tags = ["ddos-master"]
}
```

### 3-bis.5 Master startup script (`startup_scripts/master.sh`)

```bash
#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/startup.log) 2>&1

# Wait for both NICs to have IPs
for i in {1..30}; do
  if ip -4 addr show | grep -c "inet 10\." | grep -q 2; then break; fi
  sleep 1
done

# Source-based policy routing for nic1 (so NetBird responses egress via nic1)
NIC1_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/ip)
NIC1_GW=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/1/gateway)
NIC1_DEV=$(ip -o link show | awk -F': ' '$2 ~ /^ens5$|^eth1$/ {print $2; exit}')

echo "200 nic1-rt" >> /etc/iproute2/rt_tables
ip route add default via "${NIC1_GW}" dev "${NIC1_DEV}" table nic1-rt
ip rule add from "${NIC1_IP}/32" table nic1-rt

# Verification (logged for debugging)
ip rule show
ip route show table nic1-rt

# Install Python + Locust
apt-get update
apt-get install -y python3-pip
pip3 install --break-system-packages locust

# Pull all 3 locustfiles from GCS
LOCUSTFILES_BUCKET=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/locustfiles_bucket)
mkdir -p /opt/locust
gsutil cp gs://${LOCUSTFILES_BUCKET}/locustfile_attacker_hostname.py /opt/locust/
gsutil cp gs://${LOCUSTFILES_BUCKET}/locustfile_attacker_ip.py /opt/locust/
gsutil cp gs://${LOCUSTFILES_BUCKET}/locustfile_baseline.py /opt/locust/

# Create dedicated user
useradd -r -s /bin/false locust || true
chown -R locust:locust /opt/locust

# Install systemd units
cat > /etc/systemd/system/locust-master-attacker-hostname.service <<'EOF'
[Unit]
Description=Locust master (attacker-hostname)
After=network.target
[Service]
Type=simple
User=locust
ExecStart=/usr/local/bin/locust --master --master-bind-host=0.0.0.0 --master-bind-port=5557 --web-host=0.0.0.0 --web-port=8089 -f /opt/locust/locustfile_attacker_hostname.py --csv=/var/log/locust-attacker-hostname --csv-full-history
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/locust-master-attacker-ip.service <<'EOF'
[Unit]
Description=Locust master (attacker-ip)
After=network.target
[Service]
Type=simple
User=locust
ExecStart=/usr/local/bin/locust --master --master-bind-host=0.0.0.0 --master-bind-port=5558 --web-host=0.0.0.0 --web-port=8090 -f /opt/locust/locustfile_attacker_ip.py --csv=/var/log/locust-attacker-ip --csv-full-history
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/locust-master-baseline.service <<'EOF'
[Unit]
Description=Locust master (baseline)
After=network.target
[Service]
Type=simple
User=locust
ExecStart=/usr/local/bin/locust --master --master-bind-host=0.0.0.0 --master-bind-port=5559 --web-host=0.0.0.0 --web-port=8091 -f /opt/locust/locustfile_baseline.py --csv=/var/log/locust-baseline --csv-full-history
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now locust-master-attacker-hostname
systemctl enable --now locust-master-attacker-ip
systemctl enable --now locust-master-baseline
```

The `--csv` flag with `--csv-full-history` writes incremental CSV stats throughout the test, so even if a master crashes you have data up to that point.

### 3-bis.6 Worker instance templates + MIGs (`workers.tf`)

```hcl
resource "google_service_account" "worker" {
  project      = google_project.ddos_sim.project_id
  account_id   = "ddos-worker"
  display_name = "DDoS simulation worker VMs"
}

resource "google_storage_bucket_iam_member" "worker_locust_read" {
  bucket = var.locustfiles_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.worker.email}"
}

locals {
  worker_common_metadata = {
    enable-oslogin     = "TRUE"
    locustfiles_bucket = var.locustfiles_bucket
    master_nic0_ip     = google_compute_instance.master.network_interface[0].network_ip
  }
}

# attacker-hostname MIG template
resource "google_compute_instance_template" "attacker_hostname" {
  project      = google_project.ddos_sim.project_id
  name_prefix  = "atk-host-"
  machine_type = "e2-standard-2"
  region       = var.attack_region

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.attack_vpc.id
    subnetwork = google_compute_subnetwork.attack_primary.id
    access_config {} # ephemeral public IP
  }

  metadata = merge(local.worker_common_metadata, {
    master_port    = "5557"
    locustfile     = "locustfile_attacker_hostname.py"
    startup-script = file("${path.module}/startup_scripts/worker.sh")
  })

  service_account {
    email  = google_service_account.worker.email
    scopes = ["cloud-platform"]
  }

  lifecycle { create_before_destroy = true }
}

# attacker-ip MIG template — same as above except metadata
resource "google_compute_instance_template" "attacker_ip" {
  # ... identical, except:
  # metadata.master_port = "5558"
  # metadata.locustfile = "locustfile_attacker_ip.py"
  # name_prefix = "atk-ip-"
}

# baseline MIG template — same as above except metadata
resource "google_compute_instance_template" "baseline" {
  # ... identical, except:
  # metadata.master_port = "5559"
  # metadata.locustfile = "locustfile_baseline.py"
  # name_prefix = "baseline-"
}

# 3 MIGs
resource "google_compute_region_instance_group_manager" "attacker_hostname" {
  project            = google_project.ddos_sim.project_id
  name               = "attacker-hostname-mig"
  region             = var.attack_region
  base_instance_name = "atk-host"
  target_size        = 2
  version { instance_template = google_compute_instance_template.attacker_hostname.self_link }
  update_policy {
    type           = "OPPORTUNISTIC"
    minimal_action = "REPLACE"
    max_surge_fixed = 0
    max_unavailable_fixed = 1
  }
}

resource "google_compute_region_instance_group_manager" "attacker_ip" {
  # target_size = 2, template = attacker_ip
}

resource "google_compute_region_instance_group_manager" "baseline" {
  # target_size = 1, template = baseline
}
```

### 3-bis.7 Worker startup script (`startup_scripts/worker.sh`)

Single-NIC, much simpler than the original dual-NIC version:

```bash
#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/startup.log) 2>&1

# Read metadata
MASTER_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/master_nic0_ip)
MASTER_PORT=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/master_port)
LOCUSTFILES_BUCKET=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/locustfiles_bucket)
LOCUSTFILE=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/locustfile)

# Install Python + Locust
apt-get update
apt-get install -y python3-pip
pip3 install --break-system-packages locust

# Pull the appropriate locustfile
mkdir -p /opt/locust
gsutil cp "gs://${LOCUSTFILES_BUCKET}/${LOCUSTFILE}" /opt/locust/locustfile.py

useradd -r -s /bin/false locust || true
chown -R locust:locust /opt/locust

# systemd unit — worker idles, waiting for master to send "start"
cat > /etc/systemd/system/locust-worker.service <<EOF
[Unit]
Description=Locust worker
After=network.target
[Service]
Type=simple
User=locust
ExecStart=/usr/local/bin/locust --worker --master-host=${MASTER_IP} --master-port=${MASTER_PORT} -f /opt/locust/locustfile.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now locust-worker
```

**Key behavior:** worker connects to master on boot and waits. Generates zero load until you press "Start" on the master's web UI. Lifecycle control achieved.

### 3-bis.8 Locustfiles

All three are structurally identical except for `host`. Saved to a GCS bucket (managed by Terraform or uploaded manually before apply).

**`locustfile_attacker_hostname.py`:**
```python
import uuid
from locust import HttpUser, task, constant_throughput

class AttackerHostnameUser(HttpUser):
    host = "https://users.public.onukwilip.xyz"
    wait_time = constant_throughput(1.0)  # 1 task/sec per user

    @task
    def write_user(self):
        unique_email = f"u-{uuid.uuid4()}@test.local"
        self.client.post(
            "/users",
            json={"email": unique_email, "password": "x"},
            headers={"Host": "users.public.onukwilip.xyz"},
            name="POST /users",
        )
```

**`locustfile_attacker_ip.py`:** identical, except `host = "https://<global LB IP>"` (Terraform-templated from `google_compute_global_address.public_gateway.address`). The explicit `Host` header still set to the FQDN so the HTTPRoute matches.

**`locustfile_baseline.py`:** identical to `attacker_hostname` (same hostname target, same code path). Different file because it lets you tune baseline parameters independently if you decide to later (e.g., add `wait_time` jitter to make it look more like real traffic).

### 3-bis.9 Firewall rules

Two firewalls — both on attacker VPC. Shared VPC firewall for NetBird → master is **not needed** (your NetBird routing peer already lives in the GKE subnet, so traffic from your laptop arrives at the master's nic1 directly via the existing mesh).

```hcl
# IAP SSH for debugging
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

# Workers → master Locust ports (within attacker VPC)
resource "google_compute_firewall" "workers_to_master" {
  project = google_project.ddos_sim.project_id
  network = google_compute_network.attack_vpc.name
  name    = "allow-workers-to-master"

  source_ranges = [google_compute_subnetwork.attack_primary.ip_cidr_range]
  allow {
    protocol = "tcp"
    ports    = ["5557", "5558", "5559"]
  }

  target_tags = ["ddos-master"]
}
```

### 3-bis.10 DNS record

```hcl
resource "google_dns_record_set" "ddos_plane" {
  project      = var.shared_vpc_host_project
  managed_zone = var.private_dns_zone_name
  name         = "ddos-plane.internal.pe.onukwilip.xyz."
  type         = "A"
  ttl          = 60
  rrdatas      = [google_compute_instance.master.network_interface[1].network_ip]
}
```

After apply, browse from your laptop (via NetBird):
- `http://ddos-plane.internal.pe.onukwilip.xyz:8089` → attacker-hostname master
- `http://ddos-plane.internal.pe.onukwilip.xyz:8090` → attacker-ip master
- `http://ddos-plane.internal.pe.onukwilip.xyz:8091` → baseline master

---

## Updated validation sequence (replaces Phase 4 of the original plan)

### V.1 Master VM validation

SSH to master via IAP, confirm:

```bash
# Both NICs up
ip -4 addr show

# Source-based policy routing in place
ip rule show | grep nic1-rt
ip route show table nic1-rt

# All 3 Locust masters running
systemctl status locust-master-attacker-hostname
systemctl status locust-master-attacker-ip
systemctl status locust-master-baseline

# Master web UIs respond on nic1 (Shared VPC) IP
NIC1_IP=$(ip -4 addr show ens5 | awk '/inet / {print $2}' | cut -d/ -f1)
curl -s "http://${NIC1_IP}:8089/" | head -5
```

### V.2 Worker validation

Bring `attacker-hostname` MIG to size 1 first. SSH in, confirm:

```bash
# Worker connected to master
systemctl status locust-worker
journalctl -u locust-worker | tail -20  # should show "All workers connected"

# Egress IP confirmed (nic0 ephemeral public IP)
curl -s https://ifconfig.me

# Public FQDN resolves to global LB IP
dig +short users.public.onukwilip.xyz
```

On master side, the web UI at port 8089 should now show "1 worker" connected.

### V.3 End-to-end smoke test

From laptop (via NetBird), open `http://ddos-plane.internal.pe.onukwilip.xyz:8089`:

1. Set "Number of users" to 1.
2. Set "Ramp up" to 1.
3. Click "Start swarm".
4. Confirm: 1 RPS appears in the live chart, requests show as 200 in stats.
5. Click "Stop".

If all three stages work, scale up MIGs to full size and proceed to the real test.

### V.4 Cloud Armor preview-mode dry run

Before the real test, set `preview = true` on the rate-limit rule, run a 5-minute test with a single attacker VM, confirm logs show expected DENY decisions in `enforcedSecurityPolicy.outcome`, then flip preview off.

---

## Updated test execution (replaces parts of Phase 5)

### Pre-test setup

Open four browser tabs from your laptop (via NetBird):
1. `http://ddos-plane.internal.pe.onukwilip.xyz:8089` — attacker-hostname Locust UI
2. `http://ddos-plane.internal.pe.onukwilip.xyz:8090` — attacker-ip Locust UI
3. `http://ddos-plane.internal.pe.onukwilip.xyz:8091` — baseline Locust UI
4. Cloud Logging filtered to Cloud Armor decisions

Plus your existing Grafana dashboard for backend pod CPU.

### Test execution

1. **T-0:** scale all 3 MIGs to target sizes (workers connect to masters and idle).
2. **T+0:** click "Start swarm" on all three master UIs in quick succession:
   - attacker-hostname: 20 users, ramp 20/s
   - attacker-ip: 20 users, ramp 20/s
   - baseline: 4 users, ramp 4/s
3. **T+0 to T+30 min:** monitor live UIs. Expected pattern: attackers show 429s starting around T+0:30, ban-driven oscillation throughout. Baseline shows steady 200s.
4. **T+30 min:** click "Stop" on all three UIs.
5. CSV stats are saved at `/var/log/locust-*.csv*` on the master VM. Pull them down via `gcloud compute scp`.

### Kill switch

Three options, in order of granularity:
- **Stop one test only:** click "Stop" on the relevant master UI.
- **Stop all tests but leave fleet up:** `gcloud compute ssh ddos-master -- 'sudo systemctl stop locust-master-*'`
- **Nuke everything:** `terraform apply -var="ddos_attack_size=0" -var="ddos_baseline_size=0"` to scale all MIGs to 0.

---

## Updated post-test analysis

| Metric | Source | How to extract |
|---|---|---|
| Baseline availability | Locust CSV `_stats.csv` from baseline master | `(num_requests - num_failures) / num_requests` |
| Baseline p99 latency | Locust CSV from baseline master | `99%` column in stats CSV |
| Attack block rate | Cloud Logging | Count `enforcedSecurityPolicy.outcome="DENY"` ÷ total attacker request count |
| Backend pod CPU during attack | Existing Prometheus | Same query as previous load tests |
| Cycle behavior | Locust CSV `_stats_history.csv` from attacker masters | RPS column over time, look for ban/recover oscillation |

---

## Teardown

```bash
cd live/staging/ddos-simulation/
terragrunt destroy
```

The module owns the entire ddos-simulation project including the Shared VPC service-project attachment, so destroy is clean. The `staging` module retains the Cloud Armor policy and the migrated GKE Gateway — those are now part of your perimeter.

---

## Open items for you to decide before applying

1. **GCS bucket for locustfiles** — this lives in the `ddos-simulaton` module and is uploaded before the MIGs are created

2. **Master nic1 IP — static or ephemeral?** Reserve a static IP for the nic1 (shared VPC network interface), which will be added as a DNS record in the shared VPC private zone.

3. **Docker usage** — Use Docker to install and set up locust (if possible), else, just install it directly on the system and make it startup when the VM starts up