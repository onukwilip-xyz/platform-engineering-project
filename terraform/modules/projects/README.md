# `projects` module

This module creates the **two core Google Cloud projects** you’ll build on:

* a **host project** (typically holds Shared VPC + networking)
* a **service project** (typically holds GKE/VMs and other workloads)

It also applies an **organization policy** to stop Google Cloud from auto-creating a default VPC network in newly created projects.

---

## What this module creates

### 1) Organization policy: disable default network creation

```hcl
resource "google_organization_policy" "no_vpc_policy" {
  org_id     = var.org_id
  constraint = "compute.skipDefaultNetworkCreation"

  boolean_policy {
    enforced = true
  }
}
```

**What it does:** Enforces the `constraints/compute.skipDefaultNetworkCreation` policy so new projects don’t get the “default” VPC network automatically. ([Google Cloud Documentation][1])

**Why it matters:** In shared-VPC / production setups, default networks are usually noise (extra firewall rules, extra subnets, accidental exposure). This policy helps you start clean.

---

### 2) Random suffix for globally-unique project IDs

```hcl
resource "random_id" "suffix" {
  byte_length = 2
}
```

**What it does:** Generates a short random hex suffix (e.g., `-a3f1`) that gets appended to your project IDs.

**Why it matters:** Project IDs must be unique, and you can also hit a “soft delete” window where deleted projects can still block reuse for a while. A suffix avoids collisions and speeds up iteration.

---

### 3) Host + Service projects (with billing attached)

```hcl
resource "google_project" "pe_host_project" {
  name            = var.host_project
  project_id      = "${var.host_project}-${random_id.suffix.hex}"
  org_id          = var.org_id
  billing_account = var.billing_account_id
  deletion_policy = "DELETE"

  depends_on = [google_organization_policy.no_vpc_policy]
}

resource "google_project" "pe_service_project" {
  name            = var.service_project
  project_id      = "${var.service_project}-${random_id.suffix.hex}"
  org_id          = var.org_id
  billing_account = var.billing_account_id
  deletion_policy = "DELETE"

  depends_on = [google_organization_policy.no_vpc_policy]
}
```

**What it does:**

* Creates **two projects under your Organization**
* **Links billing** at creation time
* Uses `deletion_policy = "DELETE"` so Terraform can delete them later when you run `terraform destroy`

**Important note on deletion:** Google Cloud projects can be *shut down and recoverable for a period* (commonly referenced as a 30-day recovery period). ([Google Cloud Documentation][2])

---

## Outputs

```hcl
output "host_project" {
  value = google_project.pe_host_project
}

output "service_project" {
  value = google_project.pe_service_project
}
```

This exposes the created projects to other modules (networking, IAM bindings, APIs, GKE, etc.).

---

## Inputs

| Variable             |   Type | Description                                                                  |
| -------------------- | -----: | ---------------------------------------------------------------------------- |
| `org_id`             | string | Organization ID where projects will be created                               |
| `host_project`       | string | Friendly name prefix for the host project (suffix is added automatically)    |
| `service_project`    | string | Friendly name prefix for the service project (suffix is added automatically) |
| `billing_account_id` | string | Billing Account ID to link to both projects                                  |

---

## Example usage

```hcl
module "projects" {
  source             = "./modules/projects"
  org_id             = var.org_id
  host_project       = "my-host-project"
  service_project    = "my-service-project"
  billing_account_id = var.billing_account_id
}
```

---

## Required permissions (high-level)

Whichever identity runs this module (CI service account, local impersonated SA, etc.) typically needs:

* Permission to **create projects** in the org
* Permission to **link billing** to projects
* Permission to **set org policy** at the org level (because this module enforces `compute.skipDefaultNetworkCreation`) ([Google Cloud Documentation][1])

If you want this module to work in environments **without Organization access**, you can make the org policy optional (e.g., behind a variable like `enable_no_default_vpc_policy = true/false`).

---

## Design choices and rationale

* **Organization policy first, then projects** (`depends_on`)
  Ensures projects are created “clean” (no default network).
* **Random project ID suffix**
  Makes repeated testing less painful, and avoids “already exists / pending deletion” collisions.
* **Deletion policy set to `DELETE`**
  Helps Terraform manage teardown in lab/dev environments.