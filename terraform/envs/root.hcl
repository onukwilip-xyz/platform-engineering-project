# ── Root Terragrunt config ────────────────────────────────────────────────────
# This file is the single source of truth for the GCS remote state backend.
# Every unit under envs/ inherits it via `include "root"`.
#
# path_relative_to_include() resolves to the unit's path relative to this file,
# giving each unit a unique state prefix automatically. Examples:
#   staging/project/         → envs/staging/project/terraform.tfstate
#   staging/gke/             → envs/staging/gke/terraform.tfstate
#   staging/kubernetes/cert-manager/ → envs/staging/kubernetes/cert-manager/terraform.tfstate
#
# Set the bucket name via env var before running any terragrunt command:
#   export TF_STATE_BUCKET=pe-tf-state-bucket

locals {
  state_bucket = get_env("TF_STATE_BUCKET", "pe-tf-state-bucket")
}

remote_state {
  backend = "gcs"
  config = {
    bucket = local.state_bucket
    prefix = "${path_relative_to_include()}/terraform.tfstate"
  }
  # Writes a backend.tf into each unit directory at init time.
  # No backend.tf files are needed anywhere in the Terraform modules.
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}