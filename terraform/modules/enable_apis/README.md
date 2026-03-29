# Enable APIs Module (`enable_apis`)

This module **turns on (enables) the Google Cloud APIs** your platform needs *before* Terraform tries to create resources. If an API is not enabled, Terraform will usually fail with errors like “API not enabled” or “permission denied”.

---

## What this module does

It enables a **set of APIs in two projects**:

* **Host project** (usually: Shared VPC host + networking)
* **Service project** (usually: GKE + VMs + Artifact Registry + Storage)

Terraform enables APIs using `google_project_service`.

---

## Why it’s necessary

Google Cloud features are “behind” APIs. For example:

* **VPC / Subnets / Cloud Router / Cloud NAT** → use the **Compute Engine API** (`compute.googleapis.com`). Cloud NAT itself is implemented under Compute Engine. ([Google Cloud Documentation][2])
* **GKE** → uses the **Kubernetes Engine API** (`container.googleapis.com`)
* **Artifact Registry** → uses `artifactregistry.googleapis.com`
* **Storage buckets** → use `storage.googleapis.com`

If those APIs aren’t enabled first, Terraform can’t create those resources.

---

## How it works (in simple terms)

### 1) It builds API lists

You have two lists:

* `host_services_list` → APIs for the host project
* `service_services_list` → APIs for the service project

You can add more APIs without editing the module by passing:

* `extra_host_services`
* `extra_service_services`

Then it converts the lists to sets (`toset(...)`) so duplicates are removed.

### 2) It enables each API using `for_each`

Terraform loops through each API name and creates a `google_project_service` resource for it.

### 3) It uses two providers

* `google.net` enables APIs in the **host** project
* `google.platform` enables APIs in the **service** project

This is useful when you run Terraform with **different service accounts** for networking vs platform resources.

---

## Resources created

### `google_project_service.host_project_services`

Enables every API in `local.host_services` for `var.host_project`.

### `google_project_service.service_project_services`

Enables every API in `local.service_services` for `var.service_project`.

---

## About `disable_on_destroy = false`

You set:

* `disable_on_destroy = false`

Meaning: **if you destroy the Terraform resource, Terraform will not automatically disable the API**.

Why this is often helpful:

* Disabling APIs can break other resources during a destroy.
* Some teams prefer leaving APIs enabled to avoid churn.

If you want Terraform to disable APIs on teardown, change it to `true` (but expect some “in use” friction in real projects).

---

## APIs enabled by default

### Host project defaults

* `container.googleapis.com` (GKE API) ([Google Cloud Documentation][3])
* `compute.googleapis.com` (VPC, subnet, router, NAT; Cloud NAT is part of Compute Engine) ([Google Cloud Documentation][2])
* `serviceusage.googleapis.com` (so Terraform can enable other APIs)
* `iam.googleapis.com` (safe to enable; helps if you ever manage IAM-related resources in host)
* `cloudresourcemanager.googleapis.com` (safe to enable; project/org operations)
* `dns.googleapis.com` (for DNS management)

### Service project defaults

* `container.googleapis.com` (GKE API) ([Google Cloud Documentation][3])
* `compute.googleapis.com` (VMs, instance templates, etc.)
* `artifactregistry.googleapis.com` (Artifact Registry) ([Google Cloud Documentation][4])
* `storage.googleapis.com` (backup bucket)
* `serviceusage.googleapis.com`
* `iam.googleapis.com`, `iamcredentials.googleapis.com` (SA ops + impersonation flows)
* `secretmanager.googleapis.com` (Create and manage secrets in Google Secrets Manager)
* `parametermanager.googleapis.com` (Create and manage config values and parameters in Google Parameter Manager)

Recommended (to avoid “surprise missing API” later):

* `logging.googleapis.com`, `monitoring.googleapis.com` (GKE + ops visibility)
* `iap.googleapis.com` (since you’re using IAP SSH/tunneling patterns)

---

## Notes / Gotchas

### “Why do I see more APIs enabled than my list?”

That can happen because:

* Some APIs enable *dependencies* automatically.
* Some Google services auto-enable supporting APIs when you create certain resources.

So your enabled list in the Console may be larger than what Terraform explicitly enabled.

### Propagation delay

After enabling APIs, it can take a short while before the project behaves as if the API is fully ready. If you hit a weird error immediately after enabling, retry or re-run Terraform.

---

## (Optional) Quick verification commands

To list enabled APIs:

```bash
gcloud services list --enabled --project <PROJECT_ID>
```