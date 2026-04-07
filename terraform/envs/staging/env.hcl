locals {
  env    = "staging"
  region = "us-central1"
  zone   = "us-central1-a"

  tf_network_sa_email  = "tf-network@pe-terraform-project.iam.gserviceaccount.com"
  tf_platform_sa_email = "tf-platform@pe-terraform-project.iam.gserviceaccount.com"

  state_bucket = "pe-tf-state-bucket"

  # Prefix for the existing terraform/shared state (read via terraform_remote_state).
  shared_state_prefix = "shared"

  labels = {
    env  = "staging"
    team = "platform-engineering"
    managed-by = "terragrunt"
  }
}
