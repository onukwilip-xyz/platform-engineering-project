# DDoS Simulation Implementation Plan and Modifications

## Overview

This document outlines the final DDoS Simulation implementation plan for the Platform Engineering project, synthesizing the original strategy with the Locust-based control-plane modifications.

## DDoS Simulation Implementation Plan

The simulation evaluates the effectiveness of Google Cloud Armor's rate limiting and DDoS protection against our public GKE Gateway.

### Key Phases

1. **Migrate Public Istio Gateway**: Transition from a regional `google_compute_address` to a global external IP utilizing the `gke-l7-global-external-managed` Gateway class. This allows attaching Cloud Armor to the public-facing gateway.
2. **Cloud Armor Security Policy**: Apply rate limiting policies (300 requests/min throttle, 550 requests/min ban for 120s) and attach them via a `GCPBackendPolicy` to the GKE Gateway along with Adaptive Protection.
3. **Simulation Infrastructure (Locust)**: Spin up an isolated `ddos-simulation` Terragrunt module:
   - **Standalone VPC**: For outbound attack traffic egress.
   - **Shared VPC Attachment**: Exclusively for the Master VM to receive traffic securely from the local machine (via the NetBird VPN).
   - **Master VM**: Runs three Locust masters (Attacker Hostname, Attacker IP, Baseline) over distinct systemd-managed ports.
   - **Worker VMs**: 5 single-NIC VMs (2 for Attacker Hostname, 2 for Attacker IP, 1 for Baseline) idling automatically until the Master VM web UI triggers the traffic swarm.
4. **Validation Test**: Test the Master VM, Worker VMs, and Cloud Armor (in preview mode) to ensure the control-plane functions effectively before executing a full-scale assault.
5. **Execution**: Manually trigger the baseline and attack tests via the Locust web UI. The attacker VMs operate at aggressive loads (600 requests/min) to trip Cloud Armor thresholds within ~55 seconds. The baseline VM sits safely under the threshold.
6. **Teardown**: Execute `terragrunt destroy` on the isolated `ddos-simulation` module to instantly clean up the master/worker infrastructure without impacting the production-equivalent staging cluster.

## Modifications from the Original Plan (`DDOS-IMPLEMENTATION.md` vs `DDOS-SIMULATION-WITH-LOCUST.md`)

The Locust addendum fundamentally replaced Phase 3 and modified Phase 5 of the original k6-based implementation roadmap.

| Feature                | Original Plan (`DDOS-IMPLEMENTATION.md`)              | Modified Plan (`DDOS-SIMULATION-WITH-LOCUST.md`)             |
| ---------------------- | ----------------------------------------------------- | ------------------------------------------------------------ |
| **Tooling Framework**  | k6 baked directly into bash startup scripts           | Locust utilizing a decoupled Master/Worker architecture      |
| **Execution Control**  | Code auto-executes immediately upon worker VM boot    | Controlled dynamically via Locust Web UI on the Master VM    |
| **Fleet Size**         | 8 Worker VMs (4 Baseline, 2 Hostname, 2 IP)           | 1 Master VM + 5 Worker VMs (1 Baseline, 2 Hostname, 2 IP)    |
| **Network Interfaces** | Dual-NIC workers (Standalone Attack VPC + Shared VPC) | Single-NIC workers, Dual-NIC specifically on the Master VM   |
| **Observability**      | Prometheus remote-write integration directly          | Live Locust Web UI tracing + static CSV file exports         |
| **Action Profiles**    | Write/Read mix proportions (7w/3r & 2w/1r mixes)      | 100% Write generation utilizing distinct UUID payload traces |
| **DNS/Routing Logic**  | Workers utilized `/etc/hosts` to access Prometheus    | Master VM leverages source-based policy routing for NetBird  |

## Actual Implementation vs. Plans (The Current Codebase)

While the `DDOS-SIMULATION-WITH-LOCUST.md` plan formalized the overarching architecture, the actual Terraform layout adapted to distinct quotas and best practices. 

Here is what was specifically modified during the actual codebase implementation:

1. **Cloud Armor Separation & Quota Adjustments (`terraform/envs/staging/cloud-armor`)**:
   - *Plan*: Attach Cloud Armor tightly within the existing Gateway Terragrunt staging unit.
   - *Reality*: Abstracted into its own distinct unit `envs/staging/cloud-armor`. However, due to a GCP `SECURITY_POLICIES` quota limit on the staging service project, the entire `cloud-armor` terragrunt deployment is temporarily **disabled** (`exclude { if = true }` in `terragrunt.hcl`). Furthermore, the GCPBackendPolicy security bindings residing in `envs/staging/kubernetes/gateway` are temporarily commented out pending GCP quota approval.
2. **DDoS Module Structuring (`terraform/ddos-simulation/module`)**:
   - *Plan*: House the generalized module in the shared `terraform/modules/` directory alongside standard modules.
   - *Reality*: The module was co-located directly inside the simulation environment (`terraform/ddos-simulation/module`) for stricter blast-radius isolation, distinct from the shared modules used across `staging/production`.
3. **Master Static IP Injection**:
   - *Plan*: The Master's Shared VPC Network Interface (nic1) was assumed to grab any ephemeral internal IP.
   - *Reality*: A dedicated `google_compute_address.master_nic1` (Internal Address) was provisioned and attached. This ensures the master interface predictably binds over NetBird VPN.
4. **Parameterized Script Templating (`module/scripts/master.sh.tftpl`)**:
   - *Plan*: Execute static `.sh` script behaviors and hardcode Locust swarm rates.
   - *Reality*: The Locust execution was modernized via Terraform's `templatefile()`. Locust connection users, spawn rates, and runtime variables are injected securely via VM instance metadata, bypassing hardcoded scripts and allowing rapid reconfiguration directly via `terraform/ddos-simulation/staging/terragrunt.hcl` variables.

---

## Project Structure Overview

The overall workspace fundamentally consists of two major repositories: the **Platform Engineering Project** (responsible for infrastructure, deployments, and cluster management) and the **Platform Engineering Microservices** (responsible for application layer source code).

### 1. `platform-engineering-project/` (Infra & DevOps)

This repository drives the deployment, networking, and comprehensive platform provisioning logic layer utilizing Infrastructure-as-Code.

- **`helm/`**: Contains custom Helm charts utilized to template out resources effectively (such as generalizing microservice workloads).
- **`terraform/`**: The core foundation layer using Terraform for GCP and Kubernetes management.
  - **`modules/`**: A library of reusable Terraform blocks generating GCP resources (Artifact Registry, GKE, DNS, Cloud Armor, Service Networking, NetBird VPN, IAM, Cloud Storage, Host networking, etc.).
  - **`envs/`**: Extends the custom modules using Terragrunt per environment layout (`staging/`, `production/`, and `root.hcl`).
  - **`shared/`**: Common Terraform backend scaffolding scripts, provider prerequisites, and overall state setups.
  - **`kubernetes/`**: Day-two Kubernetes cluster manifests grouping toolings like ArgoCD apps, Cert-Manager configurations, Istio settings, Gateway APIs, Prom/Grafana (observability), External Secrets (eso-infra), and Postgres components (cnpg-infra).
  - **`ddos-simulation/`**: The isolated infrastructure module specifically deployed for generating synthetic loads and analyzing Cloud Armor defenses (as documented above).
  - **`load-testing/`**: Standard performance test procedures detailing the K8s manifest testing plans and runbooks.

### 2. `platform-engineering-microservices/` (Application Architectures)

This repository orchestrates the cloud-native multi-lingual microservices and UI interface architecture.

- **`cart-cna-microservice/`**: Java Spring Boot application regulating the e-commerce shopping cart, wrapped in a Gradle build lifecycle.
- **`products-cna-microservice/`**: Node.js/Express service managing dynamic product catalogs and system deals interacting structurally via `routes/` and database properties.
- **`search-cna-microservice/`**: Node.js microservice delivering search indexing attributes.
- **`users-cna-microservice/`**: Python FastAPI app commanding distinct user identities. Structures include the DB models, API routers, schema validators, and configurations.
- **`store-ui/`**: A React frontend application built atop TypeScript components. Orchestrated via NPM and deployed atop layered Nginx templates.
- **`infra/`**: Application-native configurations detailing explicit Helm charts, distinct Kubernetes resources subdivided into `apps/` & `shared-services/`, and local JMeter plan analytics.
