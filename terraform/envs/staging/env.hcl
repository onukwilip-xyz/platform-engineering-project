locals {
  env    = "staging"
  region = "us-central1"
  zone   = "us-central1-a"

  # tf_network_sa_email  = "tf-network@pe-terraform-project.iam.gserviceaccount.com"
  # tf_platform_sa_email = "tf-platform@pe-terraform-project.iam.gserviceaccount.com"

  # state_bucket = "pe-tf-state-bucket"

  tf_network_sa_email  = "tf-network@pe-terraform-project-1.iam.gserviceaccount.com"
  tf_platform_sa_email = "tf-platform@pe-terraform-project-1.iam.gserviceaccount.com"

  state_bucket = "pe-tf-state-bucket-1"

  # Prefix for the existing terraform/shared state (read via terraform_remote_state).
  shared_state_prefix = "shared"
  
  # Toggle for DDoS protection. Options: "cloudflare", "cloud-armor", "none"
  ddos_protection = "cloudflare"

  labels = {
    env  = "staging"
    team = "platform-engineering"
    managed-by = "terragrunt"
  }
}
