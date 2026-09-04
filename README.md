# Platform Engineering Project

A Kubernetes platform on Google Kubernetes Engine, built with Terraform and Terragrunt, that provisions raw cloud infrastructure, manages GitOps deployments via ArgoCD, enforces service mesh security via Istio Ambient, and delivers full-stack observability through the Grafana LGTM stack.

---

## Case Studies from this project
| **Clicking the images will direct you to its case study**

### SITE RELIABILITY ENGINEERING

[![Observability banner](<assets/Observability banner.png>)](https://confirmed-aardwolf-b44.notion.site/3c48d3a8561880c59302d7d39da3733e)

Monitored an entire Kubernetes infrastructure end-to-end, configured SLO and error budgets, measured app Service Level indicator metrics, and implemented Incident response in Google Cloud

### PLATFORM ENGINEERING

[![Built GKE Cluster to withstand 160k+ reqs in 1 hour](<assets/Built GKE Cluster to withstand 160k+ reqs in 1 hour.png>)](https://confirmed-aardwolf-b44.notion.site/3568d3a8561880aabc52cfccfa6d3f9b?v=3568d3a8561880d59927000c694afe94)

Achieved 99.99% success rate + availability on GKE infrastructure while successfully processing 𝟭𝟲𝟬𝗸+ 𝗿𝗲𝗾𝘀 𝗶𝗻 𝟭 𝗵𝗿 (~𝟯.𝟴𝗠+ 𝗿𝗲𝗾𝘀/𝗱𝗮𝘆); Also scaling PostgreSQL cluster to support 𝟭𝟴𝟬+ 𝗧𝗿𝗮𝗻𝘀𝗮𝗰𝘁𝗶𝗼𝗻𝘀/𝘀𝗲𝗰𝗼𝗻𝗱

### DEVSECOPS

[![Simulated DDoS Attack Against GKE Infra, Protecting With Cloudflare And GCP Firewall](<assets/Simulated DDoS Attack Against Gke Infra, Protecting With Cloudlfare And GCP Firewall.png>)](https://confirmed-aardwolf-b44.notion.site/3608d3a8561880a5ae6ac379cc8fecc0)

Protected GKE infras against a simulated DDoS attack; Blocked up to 𝟴𝟬% - 𝟭𝟬𝟬% of the attack traffic; While achieving a 𝟭𝟬𝟬% 𝗦𝗨𝗖𝗖𝗘𝗦𝗦 𝗥𝗔𝗧𝗘 𝗢𝗡 𝗕𝗔𝗦𝗘𝗟𝗜𝗡𝗘 (”𝗡𝗼𝗿𝗺𝗮𝗹”) REQUESTS; Protected infra 𝘂𝘀𝗶𝗻𝗴 𝗖𝗹𝗼𝘂𝗱𝗳𝗹𝗮𝗿𝗲 𝗮𝗻𝗱 𝗚𝗖𝗣 𝗙𝗶𝗿𝗲𝘄𝗮𝗹𝗹 𝗥𝘂𝗹𝗲𝘀

### PLATFORM ENGINEERING

[![CNPG on GKE case study banner](<assets/CNPG on GKE case study banner.png>)](https://app.notion.com/p/3468d3a8561880b38535ea709788499f?v=3468d3a8561880bcb481000c80a75582)

Architected a PostgreSQL cluster on GKE to 𝗪𝗜𝗧𝗛𝗦𝗧𝗔𝗡𝗗 𝗧𝗥𝗔𝗙𝗙𝗜𝗖 𝗕𝗨𝗥𝗦𝗧𝗦, properly 𝗥𝗘𝗖𝗢𝗩𝗘𝗥 𝗙𝗥𝗢𝗠 𝗗𝗜𝗦𝗔𝗦𝗧𝗘𝗥, 𝗘𝗡𝗖𝗥𝗬𝗣𝗧 𝗗𝗔𝗧𝗔 𝗔𝗧 𝗥𝗘𝗦𝗧 & 𝗜𝗡 𝗧𝗥𝗔𝗙𝗙𝗜𝗖, implement 𝗖𝗢𝗡𝗡𝗘𝗖𝗧𝗜𝗢𝗡 𝗣𝗢𝗢𝗟𝗜𝗡𝗚, and 𝗛𝗢𝗪 𝗜𝗧 𝗖𝗔𝗡 𝗕𝗘𝗡𝗘𝗙𝗜𝗧 𝗬𝗢𝗨𝗥 𝗖𝗢𝗠𝗣𝗔𝗡𝗬 𝗜𝗡𝗙𝗥𝗔

### DEVSECOPS

[![Netbird case study banner](<assets/Netbird case study banner.png>)](https://app.notion.com/p/3238d3a85618806b8946cd95cb3b7774?v=3238d3a85618805ebd57000c8d8a8caf)

Provided remote team members with 𝗣𝗥𝗜𝗩𝗔𝗧𝗘 + 𝗦𝗘𝗖𝗨𝗥𝗘 access to internal Cloud VPC resources — Netbird

### DEVSECOPS

[![Private + Public Key Infrastructure](<assets/PKI.png>)](https://app.notion.com/p/33c8d3a8561880ce884ad815ac69185f?v=33c8d3a8561880b99023000c43b19f3c)

How I 𝘀𝗲𝗰𝘂𝗿𝗲𝗹𝘆 𝗺𝗮𝗻𝗮𝗴𝗲𝗱 𝗜𝗻𝘁𝗲𝗿𝗻𝗮𝗹 & 𝗘𝘅𝘁𝗲𝗿𝗻𝗮𝗹 𝗿𝗼𝗼𝘁 𝗖𝗔𝘀 for apps 𝗶𝗻 𝗞𝘂𝗯𝗲𝗿𝗻𝗲𝘁𝗲𝘀 clusters — Self Managed TLS (internal CA) & ACME Let’s Encrypt (external CA), 𝘂𝘀𝗶𝗻𝗴 𝗖𝗲𝗿𝘁 𝗠𝗮𝗻𝗮𝗴𝗲𝗿

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Cloud Foundation](#cloud-foundation)
- [Repository Structure](#repository-structure)
- [Terraform Modules](#terraform-modules)
- [Networking Architecture](#networking-architecture)
- [Multi-Environment Support](#multi-environment-support)
- [GKE Cluster](#gke-cluster)
- [FinOps](#finops)
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

| Resource                   | Value                                                                            |
| -------------------------- | -------------------------------------------------------------------------------- |
| GCP Organization ID        | `***`                                                                            |
| Billing Account            | `***`                                                                            |
| Terraform State Bucket     | `pe-tf-state-bucket-2` (GCS, US, versioned + KMS)                                |
| Terraform Service Accounts | `tf-network`, `tf-platform` (in `pe-terraform-project-2`)                        |
| Staging Service Project    | `pe-staging-project`                                                             |
| Staging Cluster            | `pe-staging-cluster`, `us-central1`                                              |
| Container Registry         | GCP Artifact Registry (`us-central1-docker.pkg.dev/pe-staging-project-*/images`) |

Production has its own service project, cluster, and Artifact Registry repo, provisioned from the same modules but fully isolated from staging — see [Multi-Environment Support](#multi-environment-support). Environment-specific values (project IDs, cluster names) live in GCP Secret Manager tfvars secrets, not in Git.

---

## Repository Structure

```
.
├── terraform/
│   ├── shared/                   # One-time shared layer (host project, VPC, DNS) — plain Terraform
│   ├── modules/                  # Reusable Terraform modules (networking, GKE, DNS, VPN, etc.)
│   ├── envs/
│   │   ├── root.hcl              # Root Terragrunt config — single source of truth for the GCS backend
│   │   ├── staging/               # Terragrunt units for the staging environment
│   │   │   ├── env.hcl            # Staging locals (region, SA emails, subnet key, labels, ...)
│   │   │   ├── project/           # Service project + peering
│   │   │   ├── networking/        # Env-specific subnet/firewall config
│   │   │   ├── cloud-armor/       # Cloud Armor security policy
│   │   │   ├── artifact-registry/ # Artifact Registry repos for this environment
│   │   │   ├── gke/               # GKE cluster
│   │   │   ├── microservice-chart/# Microservices Helm release
│   │   │   └── kubernetes/        # Platform-layer units (see terraform/kubernetes/ below)
│   │   └── production/            # Mirrors staging/ 1:1 — isolated project, cluster, state, secrets
│   ├── kubernetes/               # Shared Kubernetes-layer Terraform, sourced by BOTH staging and
│   │   │                         # production Terragrunt units (parameterized via env.hcl inputs)
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
├── .github/workflows/            # shared-infra / staging-infra / production-infra + reusable template
└── helm/                         # Custom Helm charts
```

---

## Terraform Modules

### Infrastructure Modules (`terraform/modules/`)

| Module               | Purpose               | Key Resources                                                                                       |
| -------------------- | --------------------- | --------------------------------------------------------------------------------------------------- |
| `projects`           | GCP project lifecycle | Project creation, billing attachment                                                                |
| `iam_policies`       | IAM role bindings     | SA permissions, org-level roles                                                                     |
| `enable_apis`        | GCP API activation    | Container, Compute, DNS, Secret Manager, Monitoring, Logging                                        |
| `host_networking`    | Shared VPC            | VPC, subnets (primary + secondary pod/service ranges), NAT, Cloud Router, firewall                  |
| `dns`                | DNS zone management   | Public zone (`pe.onukwilip.xyz`), private zone (`internal.pe.onukwilip.xyz`), Cloudflare delegation |
| `gke`                | GKE cluster           | VPC-native, workload identity, VPA, private cluster with authorized networks, monitoring config     |
| `service_networking` | VPC peering           | Host ↔ service project peering                                                                      |
| `vpn-server-infra`   | Netbird VPN server    | Compute Engine instance, Let's Encrypt TLS, Secret Manager integration                              |
| `vpn-netbird-infra`  | Netbird routing       | Routing peer, Google OAuth IDP, nameserver groups, route CIDRs                                      |
| `cloud-armor`        | GCP DDoS protection   | Rate limiting (300 req/min/IP), adaptive layer-7 defense, per-IP ban thresholds                     |
| `cloudflare-ddos`    | Cloudflare DDoS       | Rate-limit rulesets, origin CA certificates                                                         |
| `artifact_registry`  | Container registry    | GCP Artifact Registry for Docker images                                                             |
| `cloud_storage`      | GCS buckets           | Backup bucket with lifecycle rules, versioning, KMS encryption                                      |

---

## Networking Architecture

### VPC & Subnets

| Resource                | CIDR / Detail                                                   |
| ----------------------- | --------------------------------------------------------------- |
| VPC                     | `pe-vpc` — shared VPC host, regional routing                    |
| GKE subnet              | `pe-gke-subnet` — `10.10.0.0/20`                                |
| Pod secondary range     | `10.20.0.0/16`                                                  |
| Service secondary range | `10.30.0.0/16`                                                  |
| GKE master CIDR         | `172.16.0.16/28`                                                |
| NAT                     | Cloud NAT on Cloud Router — outbound internet for private nodes |

### Gateways (Kubernetes Gateway API)

| Gateway | Type                             | Hostname                      | TLS                          |
| ------- | -------------------------------- | ----------------------------- | ---------------------------- |
| Public  | GCP Global External LB, port 443 | `*.pe.onukwilip.xyz`          | cert-manager (Let's Encrypt) |
| Private | GCP Internal LB, port 443        | `*.internal.pe.onukwilip.xyz` | cert-manager (internal CA)   |

### VPN — Netbird Overlay

- Netbird server on Compute Engine with Let's Encrypt TLS
- Google OAuth as identity provider for user access control
- Routing peer instance handles NAT traversal
- Private subdomains (`internal.pe.onukwilip.xyz`) routed through the Netbird peer for remote developers

---

## Multi-Environment Support

The platform now runs **staging** and **production** as structurally identical, fully isolated environments, orchestrated with Terragrunt.

### Environment Layout

- `terraform/envs/root.hcl` is the single Terragrunt root config — it defines the GCS remote-state backend once, and every unit under `envs/` inherits it. State is automatically prefixed per unit path (e.g. `envs/staging/gke/terraform.tfstate`, `envs/production/gke/terraform.tfstate`), so staging and production never share state.
- `terraform/envs/staging/env.hcl` and `terraform/envs/production/env.hcl` hold each environment's locals — region/zone, Terraform SA emails, subnet key, DDoS protection toggle, and resource labels. These are the only files that differ structurally between environments.
- Environment-specific layers (`project`, `networking`, `cloud-armor`, `artifact-registry`, `gke`, `microservice-chart`) are duplicated per environment under `envs/<env>/` — each provisions its own GCP service project, subnet, cluster, and registry.
- Platform-layer units (`kubernetes/argocd`, `argocd-apps`, `istio`, `eso-infra`, `cnpg-infra`, `observability-infra`, `tcp-services`, `priority-classes`) are **shared** — both environments' Terragrunt configs point at the same source in `terraform/kubernetes/`, parameterized per environment via `env.hcl` inputs and dependency outputs.
- `terraform/shared/` remains a one-time, plain-Terraform layer (host project, Shared VPC, DNS delegation) that both environments peer into.

### Secrets & Identity per Environment

Each environment has its own GitHub Environment (`staging`, `production`, plus `shared` and `general`), each bound to its own CI/CD service account (`cicd-sa-staging`, `cicd-sa-production`, ...) via Workload Identity Federation scoped to `attribute.environment`, and its own tfvars secret in Secret Manager (`cicd-tfvars-staging`, `cicd-tfvars-production`, `cicd-tfvars-shared`). No environment can read another's credentials or variables.

### CI/CD Pipelines

| Workflow                             | Trigger                                                                          | Applies                       |
| ------------------------------------ | --------------------------------------------------------------------------------- | ------------------------------ |
| `shared-infra.yaml`                  | Manual dispatch only                                                             | `terraform/shared/`            |
| `staging-infra.yaml`                 | Push to `staging` touching `terraform/envs/staging/**`, or manual dispatch       | `terraform/envs/staging/`      |
| `production-infra.yaml`              | Push to `main` touching `terraform/envs/production/**`, or manual dispatch       | `terraform/envs/production/`   |
| `terraform-workflow-template.yaml`   | Reusable — called by all three above                                            | —                               |

Both `staging-infra.yaml` and `production-infra.yaml` use `dorny/paths-filter` to detect whether a push touched the environment-level layers or only `kubernetes/**`, and run just the affected job — an infra-only change doesn't redeploy the platform layer and vice versa. A manual `workflow_dispatch` accepts `action` (`apply`/`destroy`) and `scope` (`all`/`kubernetes`) inputs for ad-hoc runs.

The shared reusable workflow:

- Authenticates to GCP via WIF using the service account scoped to the target GitHub Environment.
- Resolves the tfvars path dynamically from `github-environment` and `iac-tool`, then pulls that environment's tfvars from Secret Manager just-in-time — nothing sensitive is ever committed to Git.
- Optionally connects to the Netbird VPN before running Terraform/Terragrunt, since both environments' GKE control planes are only reachable privately.
- For Terragrunt runs, checks whether the environment's `project`/`gke` units are **already applied** (via `terragrunt ... output`) before installing the GKE auth plugin and fetching `kubectl` credentials — so bootstrapping a brand-new environment (no cluster yet) doesn't fail the pipeline on that step.
- Runs `terragrunt run --all <action>` (or plain `terraform <action>` for the shared layer).

---

## GKE Cluster

**Cluster:** `pe-staging-cluster` — `us-central1` — VPC-native, private, workload identity enabled

| Node Pool | Machine Type       | Max Nodes | VM Provisioning | Use                        |
| --------- | ------------------ | --------- | ---------------- | --------------------------- |
| `large`   | `e2-standard-4`    | 6         | Spot              | General workloads          |
| `small`   | `e2-standard-2`    | 3         | Spot              | Light workloads             |
| `default` | `e2-custom-2-16GB` | 3         | Spot              | Memory-intensive workloads |

All staging node pools run on GCE **Spot VMs** rather than on-demand instances — see [FinOps](#finops) for the cost rationale and how interruptions are handled.

---

## FinOps

The staging environment's GKE node pools are provisioned as **Spot VMs** (`spot = true` on each pool in `terraform/envs/staging/gke`'s `.tfvars`, wired through to `google_container_node_pool.node_config.spot` in [`terraform/modules/gke/node-pools.tf`](terraform/modules/gke/node-pools.tf)) instead of standard on-demand nodes.

- **Why Spot:** GCP prices Spot VMs at roughly 60–91% below on-demand for the same machine type, with no fixed lifetime cap (unlike the older "preemptible" flag). Staging runs interruptible, non-customer-facing workloads, so it's a direct infra cost cut with no availability guarantee to trade against.
- **Handling reclamation:** GCP can reclaim a Spot node at any time it needs the capacity back. Each node pool has `management { auto_repair = true, auto_upgrade = true }` and cluster autoscaling (`min_node_count`/`max_node_count`), so GKE re-provisions a replacement node automatically. Application-level resilience comes from the microservices' own `PodDisruptionBudget`s (`helm/custom-charts/microservice/templates/pdb.yaml`), which keep a minimum number of replicas available while a reclaimed node's pods are rescheduled elsewhere.
- **Module support:** the `spot` field is a per-node-pool boolean (`terraform/modules/gke/variables.tf`), so it can be toggled independently for each pool and each environment — it isn't an all-or-nothing cluster setting.

---

## Kubernetes Platform Layer

### ArgoCD (GitOps)

ArgoCD is deployed via Helm with Redis HA for session management (2 server replicas, 1 application controller). All platform workloads are declared as ArgoCD `Application` resources in `terraform/kubernetes/argocd-apps/applications.tf` — nothing is applied to the cluster outside of Git.

### Service Mesh — Istio Ambient Mode

Istio runs in **Ambient mode** (no per-pod sidecar for most workloads):

| Mode                   | Applied To                                                                                   |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| Ambient (ztunnel only) | All observability namespaces (`monitoring`, `grafana`, `logging`, `tracing`, `events`)       |
| Full sidecar injection | Application namespaces: `users`, `store-ui` (opt-in via `istio-injection=enabled`)           |
| Excluded               | DaemonSets that require `hostNetwork`: Alloy, node-exporter (`istio.io/dataplane-mode=none`) |
| Disabled               | `postgres` namespace — database traffic kept off-mesh                                        |

`ztunnel` handles transparent mTLS at the node level for ambient-mode namespaces. `VirtualService` and `DestinationRule` resources control traffic routing for sidecar-injected microservices.

### Certificate Management — cert-manager + trust-manager

| Issuer                 | Use                                                  | Rotation                        |
| ---------------------- | ---------------------------------------------------- | ------------------------------- |
| Internal CA            | Private services, database certs, inter-service mTLS | Server: 90 days, Client: 7 days |
| Let's Encrypt (public) | Public gateway wildcard cert                         | 90 days, auto-renewed           |

cert-manager is granted `dns.admin` via Workload Identity for DNS-01 ACME challenge validation.

### Secret Management — External Secrets Operator

ESO syncs secrets from GCP Secret Manager into Kubernetes `Secret` resources. Stored secrets include: Netbird admin credentials, Google OAuth tokens, database passwords, and PAT tokens. Pods reference `SecretStore` / `ExternalSecret` CRDs — no static credentials in Git.

### Database — CloudNativePG (CNPG)

| Attribute | Detail                                                                                       |
| --------- | -------------------------------------------------------------------------------------------- |
| Engine    | PostgreSQL 15+                                                                               |
| Topology  | 1 primary + 2 synchronous standbys, zone-spread                                              |
| Pooling   | PgBouncer connection pooler                                                                  |
| Backups   | Continuous WAL archiving + daily incremental + weekly full → `db-backups-staging` GCS bucket |
| Sizing    | VPA-managed resource allocation                                                              |

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

| Component           | Namespace    | Storage                         | Retention     |
| ------------------- | ------------ | ------------------------------- | ------------- |
| Prometheus          | `monitoring` | 10Gi PVC                        | 7 days        |
| Grafana             | `grafana`    | 5Gi PVC                         | —             |
| Loki                | `logging`    | 2Gi PVC + GCS (`loki-staging`)  | 10 days (GCS) |
| Tempo               | `tracing`    | 2Gi PVC + GCS (`tempo-staging`) | 10 days (GCS) |
| Alloy               | `logging`    | DaemonSet (no storage)          | —             |
| Kube Event Exporter | `events`     | → forwards to Loki              | —             |
| Kiali               | `tracing`    | —                               | —             |
| Jaeger              | `tracing`    | —                               | —             |

### Workload Identity for Observability

| Kubernetes SA     | GCP SA                                              | Permissions                                        |
| ----------------- | --------------------------------------------------- | -------------------------------------------------- |
| `loki-gcs`        | `loki-gcs@<project>.iam.gserviceaccount.com`        | `storage.objectUser`, `storage.legacyBucketReader` |
| `tempo-gcs`       | `tempo-gcs@<project>.iam.gserviceaccount.com`       | `storage.objectUser`, `storage.legacyBucketReader` |
| `postgres-backup` | `postgres-backup@<project>.iam.gserviceaccount.com` | `storage.objectAdmin`                              |

### Alerting & Incident Response

Grafana Alerting is provisioned entirely as code (contact points, notification policies, and rules — see [`grafana-alerting/`](terraform/kubernetes/argocd-apps/grafana-alerting)) and every rule carries an explicit `channel` label used purely for routing:

| Contact point           | Type      | Used for                                                          |
| ------------------------ | --------- | ------------------------------------------------------------------ |
| `default-catchall`       | Slack     | Unrouted / unmatched alerts                                        |
| `scale-workloads`        | Slack     | Capacity signals — CPU/memory near limit, throttling, PVC near full |
| `warning`                | Slack     | Low-urgency issues (unschedulable pods, node memory pressure)      |
| `error`                  | Slack     | Service-impacting failures (crash loops, zero-replica workloads)   |
| `critical`               | Slack     | Full outages in critical namespaces (`postgres`, `cnpg-system`)    |
| `datasource-errors`      | Slack     | Grafana datasource health (Prometheus/Loki/Tempo failures)         |
| `pagerduty-high-priority`| PagerDuty | SLO fast-burn alerts — pages a human, doesn't just post a message  |

**PagerDuty escalation.** Alerts carrying the `incident-response = "true"` label — currently the Sloth-generated SLO fast-burn burn-rate alerts — are routed to the `pagerduty-high-priority` contact point in addition to their Slack channel (`continue: true` in [`policies.yaml`](terraform/kubernetes/argocd-apps/grafana-alerting/policies.yaml)). This contact point fires a PagerDuty Events API v2 event via an integration/routing key (`PAGERDUTY_ROUTING_KEY`, injected from a Kubernetes Secret sourced from `var.pagerduty_routing_key` — see [`secrets.tf`](terraform/kubernetes/argocd-apps/secrets.tf)), tagged with `severity: critical`, `class: slo-fast-burn`, and the offending `sloth_service`/`sloth_slo` labels so responders land on the right service immediately.

**On-call rotation & Slack incident channels.** The on-call schedule and escalation policy that the routing key points to, along with PagerDuty's Slack integration that automatically spins up a dedicated incident channel per triggered PagerDuty incident, are configured directly in the PagerDuty and Slack dashboards rather than as Terraform — they sit outside this repo's IaC boundary, the same way the underlying Slack webhook URLs and PagerDuty integration key are provisioned out-of-band and only referenced here as secrets.

---

## Security Model

| Layer                | Mechanism                                                                  |
| -------------------- | -------------------------------------------------------------------------- |
| Network edge         | Cloudflare rate limiting + GCP Cloud Armor adaptive DDoS (layer 7)         |
| Ingress TLS          | cert-manager with Let's Encrypt, auto-rotating wildcard certs              |
| Service-to-service   | Istio Ambient ztunnel — transparent mTLS, no application changes needed    |
| Pod identity         | GKE Workload Identity Federation — KSA impersonates GCP SA, no static keys |
| Secret access        | External Secrets Operator syncs from GCP Secret Manager                    |
| Remote access        | Netbird VPN overlay with Google OAuth identity verification                |
| Cloud infrastructure | `tf-network` and `tf-platform` service accounts with least-privilege IAM   |

### Key Service Accounts

| SA                | Project   | Responsibilities                                  |
| ----------------- | --------- | ------------------------------------------------- |
| `tf-network`      | Terraform | Networking, VPN, DNS, Secret Manager, logging     |
| `tf-platform`     | Terraform | GKE, databases, application infrastructure        |
| `cert-manager`    | Service   | DNS-01 validation for Let's Encrypt (`dns.admin`) |
| `loki-gcs`        | Service   | GCS read/write for Loki log storage               |
| `tempo-gcs`       | Service   | GCS read/write for Tempo trace storage            |
| `postgres-backup` | Service   | GCS object admin for Barman Cloud backups         |

---

## Storage

### GCS Buckets

| Bucket                 | Purpose                         | Lifecycle            | Versioning    |
| ---------------------- | ------------------------------- | -------------------- | ------------- |
| `pe-tf-state-bucket-2` | Terraform remote state          | —                    | Enabled + KMS |
| `loki-staging`         | Loki log chunks, index, rulers  | Delete after 10 days | Enabled       |
| `tempo-staging`        | Tempo trace spans               | Delete after 10 days | Enabled       |
| `db-backups-staging`   | PostgreSQL Barman Cloud backups | 30-day minimum       | Enabled       |

### Kubernetes Persistent Volumes

| Workload          | Size                               | Storage Class |
| ----------------- | ---------------------------------- | ------------- |
| Prometheus        | 10Gi                               | `standard`    |
| Grafana           | 5Gi                                | `standard`    |
| Loki              | 2Gi                                | `standard`    |
| Tempo             | 2Gi                                | `standard`    |
| PostgreSQL (CNPG) | Per-instance PVCs for PGDATA + WAL | `standard`    |

---

## DNS Architecture

| Zone                        | Visibility           | Managed By                            | Purpose                                         |
| --------------------------- | -------------------- | ------------------------------------- | ----------------------------------------------- |
| `pe.onukwilip.xyz`          | Public               | GCP Cloud DNS → Cloudflare delegation | Public-facing services (store-ui, ArgoCD, etc.) |
| `internal.pe.onukwilip.xyz` | Private (VPC-scoped) | GCP Cloud DNS private zone            | Internal services accessible via Netbird VPN    |

DNS records (A, MX, nameserver delegation) are managed via Terraform using both the Google Cloud DNS and Cloudflare Terraform providers.

---

## Deployed Workloads (ArgoCD Applications)

All 16 ArgoCD Applications are defined in `terraform/kubernetes/argocd-apps/applications.tf`:

| #   | Application                 | Namespace          | Purpose                                                              |
| --- | --------------------------- | ------------------ | -------------------------------------------------------------------- |
| 1   | `cnpg-operator`             | `cnpg-system`      | CloudNativePG operator for PostgreSQL management                     |
| 2   | `postgres-cluster`          | `postgres`         | 3-instance HA PostgreSQL cluster + PgBouncer pooler                  |
| 3   | `kube-prometheus-stack`     | `monitoring`       | Prometheus Operator, kube-state-metrics, node-exporter, AlertManager |
| 4   | `grafana`                   | `grafana`          | Grafana visualization platform with pre-wired datasources            |
| 5   | `loki`                      | `logging`          | Loki log aggregation (single-binary, GCS backend)                    |
| 6   | `alloy`                     | `logging`          | Grafana Alloy DaemonSet — log collection via K8s API                 |
| 7   | `tempo`                     | `tracing`          | Tempo distributed tracing (GCS backend, OTLP + Jaeger)               |
| 8   | `kiali`                     | `tracing`          | Kiali service mesh observability UI                                  |
| 9   | `jaeger`                    | `tracing`          | Jaeger legacy trace UI                                               |
| 10  | `istio-telemetry`           | `istio-system`     | Telemetry resources activating Tempo as trace backend                |
| 11  | `istio-monitors`            | `monitoring`       | Prometheus ServiceMonitors for Istio/Envoy metrics                   |
| 12  | `kubernetes-event-exporter` | `events`           | Kubernetes events → Loki pipeline                                    |
| 13  | `external-secrets`          | `external-secrets` | ESO — GCP Secret Manager → Kubernetes Secrets sync                   |
| 14  | `users-microservice`        | `users`            | Users FastAPI microservice (Istio sidecar injected)                  |
| 15  | `store-ui`                  | `store-ui`         | React frontend (Istio sidecar injected)                              |
| 16  | `k6-operator`               | `k6-operator`      | K6 load testing operator + test manifests                            |

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

Infrastructure is normally applied through the [CI/CD pipelines](#multi-environment-support) (`staging-infra.yaml` / `production-infra.yaml`), which handle WIF auth, tfvars retrieval from Secret Manager, and VPN connectivity automatically. To run Terragrunt locally against an environment, pick `staging` or `production`:

```bash
# Environment-level layers (project, networking, cloud-armor, artifact-registry, gke, microservice-chart)
cd terraform/envs/staging   # or: terraform/envs/production
terragrunt run --all init
terragrunt run --all plan
terragrunt run --all apply
```

### Applying Kubernetes Platform Layer

```bash
# Deploy the shared platform-layer units for the same environment
cd terraform/envs/staging/kubernetes   # or: terraform/envs/production/kubernetes
terragrunt run --all init
terragrunt run --all apply
```

ArgoCD will sync all declared Applications from Git automatically after this point.

### Accessing Grafana

Grafana is exposed on the private gateway at `https://grafana.internal.pe.onukwilip.xyz`. Connect via Netbird VPN first.

### Accessing ArgoCD

ArgoCD UI is exposed on the private gateway at `https://argocd.internal.pe.onukwilip.xyz`.

---

## Documentation

| File                                                                 | Content                                                               |
| -------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `terraform/README.md`                                                | GCP setup guide, service account creation, Terraform workflow         |
| `terraform/kubernetes/argocd-apps/docs/observability.md`             | Observability stack design for hybrid Istio Ambient                   |
| `terraform/kubernetes/argocd-apps/docs/3rd-party.md`                 | CNPG, Redis, MongoDB, ElasticSearch architecture with TLS and backups |
| `terraform/kubernetes/argocd-apps/docs/grafana-provisioning-plan.md` | Grafana datasource & dashboard provisioning plan                      |
| `terraform/kubernetes/argocd-apps/docs/grafana-alerting-plan.md`     | Grafana alerting rules & notification channels                        |
| `terraform/load-testing/LOAD-TESTING.md`                             | K6 load test framework and results analysis                           |
| `terraform/ddos-simulation/DDOS-IMPLEMENTATION.md`                   | DDoS protection implementation details                                |
