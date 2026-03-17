# IAM Policies Module (GCP / Terraform)

This module **grants the minimum IAM roles your Terraform service accounts need** to manage resources across a **host project** (networking) and a **service project** (compute/platform).

It’s designed for a common split-of-duties setup:

- **tf-network SA** → manages **networking** in the **host project**
- **tf-platform SA** → manages **platform/compute** in the **service project**
- *(optional)* also grants **Shared VPC subnet access** when your service-project resources must attach to subnets in the host project.

> Why use `google_project_iam_member`?\
> It’s the “add one member to one role” style of IAM management (non-authoritative), which helps reduce accidental overwrites compared to “authoritative” IAM resources

---

## What this module creates

### 1) Host project permissions (for **tf-network** SA)

These bindings are applied to the **host project**, so the network SA can create/modify networking and enable APIs:

- `roles/compute.networkAdmin`  
  Lets Terraform create/manage VPCs, subnets, routes, firewall rules, Cloud NAT pieces, etc.

- `roles/serviceusage.serviceUsageAdmin`  
  Lets Terraform enable required APIs in the host project (the role includes `serviceusage.services.enable`).
---

### 2) Service project permissions (for **tf-platform** SA)

These bindings are applied to the **service project**, so the platform SA can create and manage your “workloads” layer:

- `roles/container.admin`  
  Create/manage GKE clusters and related resources.

- `roles/compute.instanceAdmin.v1`  
  Create/manage VMs (e.g., your access VM, Headscale VM, bridge VM).

- `roles/iam.serviceAccountCreator`  
  Create service accounts (e.g., node pool SA, VM SA).

- `roles/iam.serviceAccountUser`  
  Required to let resources *run as* a service account (for example, attaching a VM’s service account, or using a custom node pool SA).

- `roles/artifactregistry.admin`  
  Create/manage Artifact Registry repos.

- `roles/storage.admin`  
  Create/manage GCS buckets (e.g., backup bucket).

- `roles/serviceusage.serviceUsageAdmin`  
  Enable required APIs in the service project.
---

## Inputs

Typical variables this module expects:

* `host_project` (string) — Host project ID
* `service_project` (string) — Service project ID
* `tf_network_sa_email` (string) — `tf-network@...`
* `tf_platform_sa_email` (string) — `tf-platform@...`
* `region` (string) — Needed only if you enable the subnet IAM block
* `gke_subnet` (string) — Needed only if you enable the subnet IAM block

---

## How to use

Call this module **after** your projects are created, and make your “network” and “platform” modules depend on it.
---

## Notes / gotchas

* **IAM & API enablement can take time to propagate.** If you see occasional “permission denied” right after apply, a short wait/retry is often enough.
* If you later tighten permissions, do it iteratively: remove one role, run `plan`, and see what breaks—then adjust.