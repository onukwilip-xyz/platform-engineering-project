# Networking Module (Host VPC + Shared VPC + NAT + IAP SSH)

This module sets up the **network foundation** for a “host + service project” platform on Google Cloud:

- A **custom VPC** in the **host project**
- A **private subnet** (with **secondary IP ranges** for GKE Pods & Services)
- Optional **Cloud NAT** (so private instances/nodes can reach the internet for updates/images)
- **Shared VPC** enabled on the host project, with the service project attached
- A secure **SSH via IAP** firewall rule (only for instances with the `ssh` network tag)
- **Subnet IAM** so approved principals can use the Shared VPC subnet (`roles/compute.networkUser`)

---

## What this module creates

### 1) VPC network (host project)
Creates a **custom-mode** VPC (no auto subnets). This keeps networking predictable and avoids surprise subnets.

### 2) Private subnet (host project)
Creates one subnet for your platform (and your GKE cluster), with:
- Primary CIDR (node / VM IP space)
- Secondary ranges:
  - **Pods** range (GKE VPC-native)
  - **Services** range (ClusterIP services)

### 3) Cloud NAT (optional, host project)
If `enable_nat = true`, creates:
- A Cloud Router (regional)
- A Cloud NAT config that NATs traffic from the subnet

This is what lets **private** VMs / GKE nodes reach the internet (e.g., OS updates, pulling images from public registries, etc.) without public IPs.

### 4) Shared VPC (host + service project)
Enables Shared VPC on the host project and attaches the service project.  
After this, resources in the service project can use host-project subnets.

### 5) Firewall: allow SSH via IAP (host project)
Creates an ingress rule that allows TCP/22 **only** from Google IAP’s TCP forwarding IP range, and **only** to instances tagged `ssh`.

This is a common pattern for “no public IP SSH access”.

### 6) Subnet IAM: `compute.networkUser`
Grants `roles/compute.networkUser` on the subnet to a set of principals (service accounts).  
This is required so service-project components (like GKE) can actually *use* the shared subnet.

---

## Prerequisites / permissions (important)

To enable Shared VPC and attach service projects, the identity running Terraform needs Shared VPC admin-level permissions at the org/folder level (commonly the **Compute Shared VPC Admin** role). In practice, this is why people grant `roles/compute.xpnAdmin` to their “network Terraform SA”.

Also, for GKE Shared VPC setups, the **service project’s GKE service agent** typically needs `roles/container.hostServiceAgentUser` on the **host project** (project-level), because it performs network operations in the host project on behalf of the service project.

---

## Inputs

Typical inputs you’ll pass:

- `host_project_id`
- `service_project_id`
- `service_project_number` (needed to form the service agent emails)
- `region`

- `vpc_name`
- `subnet_name`
- `subnet_cidr`

- `pods_secondary_range_name`
- `pods_secondary_cidr`
- `services_secondary_range_name`
- `services_secondary_cidr`

- `enable_nat` (bool)

- `tf_platform_sa_email` (so your “platform Terraform SA” can read/use the subnet)
- `extra_subnet_network_users` (optional list of extra principals)

---

## Outputs

- `vpc` (full network resource)
- `subnet` (full subnet resource)
- `pods_secondary_range_name`
- `services_secondary_range_name`

---

## Edge cases this module covers (and common gotchas)

- **Shared VPC ordering:** service project must be attached to the host project before subnet IAM grants are reliably useful (module enforces this dependency).
- **Secondary ranges must be valid and non-overlapping:** choose CIDRs that don’t overlap each other (and don’t conflict with your existing networks).
- **Regional consistency:** Cloud Router/NAT are regional; your subnet and NAT router must be in the same region.
- **No NAT = limited egress:** if you turn NAT off, private nodes/VMs may not be able to fetch updates or pull images from public registries unless you have another egress path.
- **IAP SSH requires the `ssh` network tag:** if your VM doesn’t have the tag, the rule won’t apply (intentionally).

---

## Example usage

```hcl
module "networking" {
  source = "./modules/networking"
  providers = { google = google.net }

  host_project_id        = module.projects.host_project.project_id
  service_project_id     = module.projects.service_project.project_id
  service_project_number = module.projects.service_project.number
  region                 = "us-central1"

  vpc_name    = "org-vpc"
  subnet_name = "gke-subnet"
  subnet_cidr = "10.1.0.0/20"

  pods_secondary_range_name     = "pods-ip"
  pods_secondary_cidr           = "10.2.0.0/19"
  services_secondary_range_name = "services-ip"
  services_secondary_cidr       = "10.3.0.0/19"

  enable_nat           = true
  tf_platform_sa_email = var.tf_platform_sa_email
}
```

### Notes

- This module is intentionally generic: you can reuse it for most “Shared VPC + private GKE” platforms.
- You can extend it with more firewall rules, more subnets (multi-tier), or additional service projects as your platform grows
