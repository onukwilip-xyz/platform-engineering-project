# Platform Engineering Project

A production-grade Kubernetes platform on GCP, built with Terraform and Terragrunt, that provisions raw cloud infrastructure, manages GitOps deployments via ArgoCD, enforces service mesh security via Istio Ambient, and delivers full-stack observability through the Grafana LGTM stack.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Cloud Foundation](#cloud-foundation)
- [Repository Structure](#repository-structure)
- [Terraform Modules](#terraform-modules)
- [Networking Architecture](#networking-architecture)
- [GKE Cluster](#gke-cluster)
- [Kubernetes Platform Layer](#kubernetes-platform-layer)
- [Observability Stack](#observability-stack)
- [Security Model](#security-model)
- [Storage](#storage)
- [DNS Architecture](#dns-architecture)
- [Deployed Workloads (ArgoCD Applications)](#deployed-workloads-argocd-applications)
- [Load Testing & DDoS Simulation](#load-testing--ddos-simulation)
- [Getting Started](#getting-started)

---

## Architecture Overview

```
Internet
  ├── Cloudflare  (DNS + DDoS rate limiting)
  │     └── *.pe.onukwilip.xyz  ──►  GCP Global Load Balancer  (Cloud Armor adaptive DDoS)
  │                                        └── Public Gateway (443 HTTPS, cert-manager TLS)
  │                                               └── GKE workloads (Istio Ambient mTLS)
  │
  └── Netbird VPN (remote access)
        └── *.internal.pe.onukwilip.xyz  ──►  GCP Internal Load Balancer
                                                └── Private Gateway (443 HTTPS)
                                                       └── Internal GKE services

GCP Host Project (Shared VPC)
  └── pe-vpc
        └── pe-gke-subnet        10.10.0.0/20
              ├── Pod CIDR:       10.20.0.0/16
              ├── Service CIDR:   10.30.0.0/16
              └── GKE master:     172.16.0.16/28
```

**Core design principles:**
- Shared VPC host/service project split — networking and compute are independently managed
- Istio Ambient mode — transparent mTLS without per-pod sidecar overhead
- GitOps via ArgoCD — all Kubernetes workloads declared in Git, never applied ad-hoc
- Workload Identity Federation — no static credentials; pods authenticate to GCP APIs via KSA→GSA binding
- Full-stack observability — metrics (Prometheus), logs (Loki), traces (Tempo), events (Kube Event Exporter), visualization (Grafana)

---

## Cloud Foundation

| Resource | Value |
|---|---|
| GCP Organization ID | `1034410590770` |
| Billing Account | `011B25-F5FCD8-43553E` |
| Terraform State Bucket | `pe-tf-state-bucket-1` (GCS, US, versioned + KMS) |
| Terraform Service Accounts | `tf-network`, `tf-platform` (in `pe-terraform-project-1`) |
| Staging Service Project | `pe-staging-project` |
| Staging Cluster | `pe-staging-cluster`, `us-central1` |
| Container Registry | GCP Artifact Registry (`us-central1-docker.pkg.dev/pe-staging-project-*/images`) |

---

## Repository Structure

```
.
├── terraform/
│   ├── modules/                  # Reusable Terraform modules (networking, GKE, DNS, VPN, etc.)
│   ├── envs/
│   │   └── staging/              # Terragrunt environment config for staging
│   ├── kubernetes/               # Kubernetes-level Terraform (ArgoCD apps, operators, manifests)
│   │   ├── argocd/               # ArgoCD Helm deployment
│   │   ├── argocd-apps/          # All ArgoCD Application resources + Alloy config
│   │   │   ├── config/           # Alloy log collection config
│   │   │   ├── docs/             # Design docs (observability, 3rd-party services, alerting)
│   │   │   └── grafana-dashboards/ # Grafana dashboard JSON manifests
│   │   ├── cert-manager/         # cert-manager Helm deployment
│   │   ├── cert-manager-config/  # ClusterIssuers, certificate templates
│   │   ├── gateway/              # Public + private Gateway API resources, HTTPRoutes
│   │   ├── istio/                # Istio Ambient mode deployment
│   │   ├── cnpg-infra/           # CloudNativePG operator
│   │   ├── eso-infra/            # External Secrets Operator
│   │   ├── observability-infra/  # GCS buckets + Workload Identity for Loki & Tempo
│   │   ├── load-testing/         # K6 operator + test manifests
│   │   └── manifests/            # Raw Kubernetes manifests (postgres, users, istio-monitors)
│   ├── load-testing/             # Load testing runbooks and JMeter/K6 configs
│   └── ddos-simulation/          # Locust-based DDoS simulation on Compute Engine MIGs
└── helm/                         # Custom Helm charts
```

---

## Terraform Modules

### Infrastructure Modules (`terraform/modules/`)

| Module | Purpose | Key Resources |
|---|---|---|
| `projects` | GCP project lifecycle | Project creation, billing attachment |
| `iam_policies` | IAM role bindings | SA permissions, org-level roles |
| `enable_apis` | GCP API activation | Container, Compute, DNS, Secret Manager, Monitoring, Logging |
| `host_networking` | Shared VPC | VPC, subnets (primary + secondary pod/service ranges), NAT, Cloud Router, firewall |
| `dns` | DNS zone management | Public zone (`pe.onukwilip.xyz`), private zone (`internal.pe.onukwilip.xyz`), Cloudflare delegation |
| `gke` | GKE cluster | VPC-native, workload identity, VPA, private cluster with authorized networks, monitoring config |
| `service_networking` | VPC peering | Host ↔ service project peering |
| `vpn-server-infra` | Netbird VPN server | Compute Engine instance, Let's Encrypt TLS, Secret Manager integration |
| `vpn-netbird-infra` | Netbird routing | Routing peer, Google OAuth IDP, nameserver groups, route CIDRs |
| `cloud-armor` | GCP DDoS protection | Rate limiting (300 req/min/IP), adaptive layer-7 defense, per-IP ban thresholds |
| `cloudflare-ddos` | Cloudflare DDoS | Rate-limit rulesets, origin CA certificates |
| `artifact_registry` | Container registry | GCP Artifact Registry for Docker images |
| `cloud_storage` | GCS buckets | Backup bucket with lifecycle rules, versioning, KMS encryption |

---

## Networking Architecture

### VPC & Subnets

| Resource | CIDR / Detail |
|---|---|
| VPC | `pe-vpc` — shared VPC host, regional routing |
| GKE subnet | `pe-gke-subnet` — `10.10.0.0/20` |
| Pod secondary range | `10.20.0.0/16` |
| Service secondary range | `10.30.0.0/16` |
| GKE master CIDR | `172.16.0.16/28` |
| NAT | Cloud NAT on Cloud Router — outbound internet for private nodes |

### Gateways (Kubernetes Gateway API)

| Gateway | Type | Hostname | TLS |
|---|---|---|---|
| Public | GCP Global External LB, port 443 | `*.pe.onukwilip.xyz` | cert-manager (Let's Encrypt) |
| Private | GCP Internal LB, port 443 | `*.internal.pe.onukwilip.xyz` | cert-manager (internal CA) |

### VPN — Netbird Overlay

- Netbird server on Compute Engine with Let's Encrypt TLS
- Google OAuth as identity provider for user access control
- Routing peer instance handles NAT traversal
- Private subdomains (`internal.pe.onukwilip.xyz`) routed through the Netbird peer for remote developers

---

## GKE Cluster

**Cluster:** `pe-staging-cluster` — `us-central1` — VPC-native, private, workload identity enabled

| Node Pool | Machine Type | Max Nodes | Use |
|---|---|---|---|
| `large` | `e2-standard-4` | 6 | General workloads |
| `small` | `e2-standard-2` | 3 | Light workloads |
| `default` | `e2-custom-2-16GB` | 3 | Memory-intensive workloads |

---

## Kubernetes Platform Layer

### ArgoCD (GitOps)

ArgoCD is deployed via Helm with Redis HA for session management (2 server replicas, 1 application controller). All platform workloads are declared as ArgoCD `Application` resources in `terraform/kubernetes/argocd-apps/applications.tf` — nothing is applied to the cluster outside of Git.

### Service Mesh — Istio Ambient Mode

Istio runs in **Ambient mode** (no per-pod sidecar for most workloads):

| Mode | Applied To |
|---|---|
| Ambient (ztunnel only) | All observability namespaces (`monitoring`, `grafana`, `logging`, `tracing`, `events`) |
| Full sidecar injection | Application namespaces: `users`, `store-ui` (opt-in via `istio-injection=enabled`) |
| Excluded | DaemonSets that require `hostNetwork`: Alloy, node-exporter (`istio.io/dataplane-mode=none`) |
| Disabled | `postgres` namespace — database traffic kept off-mesh |

`ztunnel` handles transparent mTLS at the node level for ambient-mode namespaces. `VirtualService` and `DestinationRule` resources control traffic routing for sidecar-injected microservices.

### Certificate Management — cert-manager + trust-manager

| Issuer | Use | Rotation |
|---|---|---|
| Internal CA | Private services, database certs, inter-service mTLS | Server: 90 days, Client: 7 days |
| Let's Encrypt (public) | Public gateway wildcard cert | 90 days, auto-renewed |

cert-manager is granted `dns.admin` via Workload Identity for DNS-01 ACME challenge validation.

### Secret Management — External Secrets Operator

ESO syncs secrets from GCP Secret Manager into Kubernetes `Secret` resources. Stored secrets include: Netbird admin credentials, Google OAuth tokens, database passwords, and PAT tokens. Pods reference `SecretStore` / `ExternalSecret` CRDs — no static credentials in Git.

### Database — CloudNativePG (CNPG)

| Attribute | Detail |
|---|---|
| Engine | PostgreSQL 15+ |
| Topology | 1 primary + 2 synchronous standbys, zone-spread |
| Pooling | PgBouncer connection pooler |
| Backups | Continuous WAL archiving + daily incremental + weekly full → `db-backups-staging` GCS bucket |
| Sizing | VPA-managed resource allocation |

---

## Observability Stack

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Collection                                                          │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │  Alloy (DaemonSet)                                       │       │
│  │  K8s API pod discovery → loki.source.kubernetes          │       │
│  │  Filters: istio-proxy logs labeled separately            │       │
│  │           event-exporter logs dropped (Loki handles)     │       │
│  └───────────────────────┬──────────────────────────────────┘       │
│                           │                                          │
│  ┌────────────────────────▼──────────┐  ┌────────────────────────┐  │
│  │  Loki  (single-binary)            │◄─│  Kube Event Exporter   │  │
│  │  Backend: GCS loki-staging        │  │  K8s events → Loki     │  │
│  │  Schema: TSDB, 24h periods        │  └────────────────────────┘  │
│  └────────────────────────┬──────────┘                              │
│                            │                                         │
│  ┌─────────────────────────▼─────────┐                              │
│  │  Prometheus  (kube-prometheus)    │                              │
│  │  Scrapes: all namespaces          │                              │
│  │  Includes: Envoy metrics (15020)  │                              │
│  │  Retention: 7d, 10Gi PVC         │                              │
│  └─────────────────────────┬─────────┘                              │
│                             │                                        │
│  ┌──────────────────────────▼────────┐                              │
│  │  Tempo                            │                              │
│  │  OTLP gRPC :4317, HTTP :4318      │                              │
│  │  Jaeger legacy support            │                              │
│  │  Backend: GCS tempo-staging       │                              │
│  │  Service graph generation enabled │                              │
│  └──────────────────────────┬────────┘                              │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Grafana            │
                    │  Datasources:       │
                    │   - Prometheus      │
                    │   - Loki            │
                    │   - Tempo           │
                    │  5Gi PVC            │
                    │  Private Gateway    │
                    └─────────────────────┘
                    ┌─────────────────────┐
                    │  Kiali              │
                    │  Istio mesh UI      │
                    │  Traffic topology   │
                    └─────────────────────┘
```

### Component Summary

| Component | Namespace | Storage | Retention |
|---|---|---|---|
| Prometheus | `monitoring` | 10Gi PVC | 7 days |
| Grafana | `grafana` | 5Gi PVC | — |
| Loki | `logging` | 2Gi PVC + GCS (`loki-staging`) | 10 days (GCS) |
| Tempo | `tracing` | 2Gi PVC + GCS (`tempo-staging`) | 10 days (GCS) |
| Alloy | `logging` | DaemonSet (no storage) | — |
| Kube Event Exporter | `events` | → forwards to Loki | — |
| Kiali | `tracing` | — | — |
| Jaeger | `tracing` | — | — |

### Workload Identity for Observability

| Kubernetes SA | GCP SA | Permissions |
|---|---|---|
| `loki-gcs` | `loki-gcs@<project>.iam.gserviceaccount.com` | `storage.objectUser`, `storage.legacyBucketReader` |
| `tempo-gcs` | `tempo-gcs@<project>.iam.gserviceaccount.com` | `storage.objectUser`, `storage.legacyBucketReader` |
| `postgres-backup` | `postgres-backup@<project>.iam.gserviceaccount.com` | `storage.objectAdmin` |

---

## Security Model

| Layer | Mechanism |
|---|---|
| Network edge | Cloudflare rate limiting + GCP Cloud Armor adaptive DDoS (layer 7) |
| Ingress TLS | cert-manager with Let's Encrypt, auto-rotating wildcard certs |
| Service-to-service | Istio Ambient ztunnel — transparent mTLS, no application changes needed |
| Pod identity | GKE Workload Identity Federation — KSA impersonates GCP SA, no static keys |
| Secret access | External Secrets Operator syncs from GCP Secret Manager |
| Remote access | Netbird VPN overlay with Google OAuth identity verification |
| Cloud infrastructure | `tf-network` and `tf-platform` service accounts with least-privilege IAM |

### Key Service Accounts

| SA | Project | Responsibilities |
|---|---|---|
| `tf-network` | Terraform | Networking, VPN, DNS, Secret Manager, logging |
| `tf-platform` | Terraform | GKE, databases, application infrastructure |
| `cert-manager` | Service | DNS-01 validation for Let's Encrypt (`dns.admin`) |
| `loki-gcs` | Service | GCS read/write for Loki log storage |
| `tempo-gcs` | Service | GCS read/write for Tempo trace storage |
| `postgres-backup` | Service | GCS object admin for Barman Cloud backups |

---

## Storage

### GCS Buckets

| Bucket | Purpose | Lifecycle | Versioning |
|---|---|---|---|
| `pe-tf-state-bucket-1` | Terraform remote state | — | Enabled + KMS |
| `loki-staging` | Loki log chunks, index, rulers | Delete after 10 days | Enabled |
| `tempo-staging` | Tempo trace spans | Delete after 10 days | Enabled |
| `db-backups-staging` | PostgreSQL Barman Cloud backups | 30-day minimum | Enabled |

### Kubernetes Persistent Volumes

| Workload | Size | Storage Class |
|---|---|---|
| Prometheus | 10Gi | `standard` |
| Grafana | 5Gi | `standard` |
| Loki | 2Gi | `standard` |
| Tempo | 2Gi | `standard` |
| PostgreSQL (CNPG) | Per-instance PVCs for PGDATA + WAL | `standard` |

---

## DNS Architecture

| Zone | Visibility | Managed By | Purpose |
|---|---|---|---|
| `pe.onukwilip.xyz` | Public | GCP Cloud DNS → Cloudflare delegation | Public-facing services (store-ui, ArgoCD, etc.) |
| `internal.pe.onukwilip.xyz` | Private (VPC-scoped) | GCP Cloud DNS private zone | Internal services accessible via Netbird VPN |

DNS records (A, MX, nameserver delegation) are managed via Terraform using both the Google Cloud DNS and Cloudflare Terraform providers.

---

## Deployed Workloads (ArgoCD Applications)

All 16 ArgoCD Applications are defined in `terraform/kubernetes/argocd-apps/applications.tf`:

| # | Application | Namespace | Purpose |
|---|---|---|---|
| 1 | `cnpg-operator` | `cnpg-system` | CloudNativePG operator for PostgreSQL management |
| 2 | `postgres-cluster` | `postgres` | 3-instance HA PostgreSQL cluster + PgBouncer pooler |
| 3 | `kube-prometheus-stack` | `monitoring` | Prometheus Operator, kube-state-metrics, node-exporter, AlertManager |
| 4 | `grafana` | `grafana` | Grafana visualization platform with pre-wired datasources |
| 5 | `loki` | `logging` | Loki log aggregation (single-binary, GCS backend) |
| 6 | `alloy` | `logging` | Grafana Alloy DaemonSet — log collection via K8s API |
| 7 | `tempo` | `tracing` | Tempo distributed tracing (GCS backend, OTLP + Jaeger) |
| 8 | `kiali` | `tracing` | Kiali service mesh observability UI |
| 9 | `jaeger` | `tracing` | Jaeger legacy trace UI |
| 10 | `istio-telemetry` | `istio-system` | Telemetry resources activating Tempo as trace backend |
| 11 | `istio-monitors` | `monitoring` | Prometheus ServiceMonitors for Istio/Envoy metrics |
| 12 | `kubernetes-event-exporter` | `events` | Kubernetes events → Loki pipeline |
| 13 | `external-secrets` | `external-secrets` | ESO — GCP Secret Manager → Kubernetes Secrets sync |
| 14 | `users-microservice` | `users` | Users FastAPI microservice (Istio sidecar injected) |
| 15 | `store-ui` | `store-ui` | React frontend (Istio sidecar injected) |
| 16 | `k6-operator` | `k6-operator` | K6 load testing operator + test manifests |

---

## Load Testing & DDoS Simulation

### Load Testing (K6)

The K6 operator is deployed to the cluster. Test manifests in `terraform/kubernetes/load-testing/` define:
- **Baseline tests** — normal traffic patterns to establish performance benchmarks
- **Attack scenario tests** — spike and stress patterns

Runbooks in `terraform/load-testing/`:
- `LOAD-TESTING.md` — framework overview and results analysis
- `LOAD-TESTING-RUNBOOK.md` — step-by-step test execution
- `LOAD-TESTING-MONITORING.md` — metrics collection and dashboard guidance during tests

### DDoS Simulation (Locust)

`terraform/ddos-simulation/` provisions Compute Engine Managed Instance Groups running Locust for realistic DDoS traffic generation. Design docs:
- `DDOS-SIMULATION-WITH-LOCUST.md` — simulation infrastructure setup
- `DDOS-IMPLEMENTATION.md` — Cloud Armor rules, Cloudflare rate limiting, and mitigation strategies

---

## Getting Started

### Prerequisites

- GCP account with Organization and Billing Account
- `terraform` and `terragrunt` installed
- `gcloud` CLI authenticated
- `kubectl` configured for the cluster
- `helm` installed

### Terraform Initialization

```bash
# Initialize state backend and providers
cd terraform/envs/staging
terragrunt run-all init

# Plan infrastructure changes
terragrunt run-all plan

# Apply
terragrunt run-all apply
```

### Applying Kubernetes Platform Layer

```bash
# Deploy ArgoCD first
cd terraform/kubernetes/argocd
terraform init && terraform apply

# Deploy all ArgoCD Applications
cd terraform/kubernetes/argocd-apps
terraform init && terraform apply
```

ArgoCD will sync all declared Applications from Git automatically after this point.

### Accessing Grafana

Grafana is exposed on the private gateway at `https://grafana.internal.pe.onukwilip.xyz`. Connect via Netbird VPN first.

### Accessing ArgoCD

ArgoCD UI is exposed on the private gateway at `https://argocd.internal.pe.onukwilip.xyz`.

---

## Documentation

| File | Content |
|---|---|
| `terraform/README.md` | GCP setup guide, service account creation, Terraform workflow |
| `terraform/kubernetes/argocd-apps/docs/observability.md` | Observability stack design for hybrid Istio Ambient |
| `terraform/kubernetes/argocd-apps/docs/3rd-party.md` | CNPG, Redis, MongoDB, ElasticSearch architecture with TLS and backups |
| `terraform/kubernetes/argocd-apps/docs/grafana-provisioning-plan.md` | Grafana datasource & dashboard provisioning plan |
| `terraform/kubernetes/argocd-apps/docs/grafana-alerting-plan.md` | Grafana alerting rules & notification channels |
| `terraform/load-testing/LOAD-TESTING.md` | K6 load test framework and results analysis |
| `terraform/ddos-simulation/DDOS-IMPLEMENTATION.md` | DDoS protection implementation details |
