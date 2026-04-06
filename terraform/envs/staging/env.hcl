# ── Staging environment locals ────────────────────────────────────────────────
# Non-sensitive values shared across every unit in this environment.
# Sensitive values (org_id, billing_account_id, passwords, tokens) go in
# secrets.tfvars (gitignored) alongside the unit that needs them.
#
# Units read this file with:
#   locals {
#     env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
#   }

locals {
  env    = "staging"
  region = "us-central1" # ← your GCP region
  zone   = "us-central1-a" # ← your GCP zone

  # Service accounts used for provider impersonation.
  # These are not secrets — they are resource identifiers.
  tf_network_sa_email  = "tf-network-sa@<HOST_PROJECT_ID>.iam.gserviceaccount.com"  # ← fill in
  tf_platform_sa_email = "tf-platform-sa@<SERVICE_PROJECT_ID>.iam.gserviceaccount.com" # ← fill in

  # GCS bucket holding all Terraform state files.
  # Must match the TF_STATE_BUCKET env var set before terragrunt commands.
  state_bucket = "pe-tf-state-bucket" # ← fill in

  # Prefix for the existing terraform/shared state (read via terraform_remote_state).
  shared_state_prefix = "shared"

  labels = {
    env        = "staging"
    team       = "platform-engineering"
    managed-by = "terragrunt"
  }
}