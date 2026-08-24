locals {
  env    = "staging"
  region = "us-central1"
  zone   = "us-central1-a"

  tf_network_sa_email  = get_env("TF_NETWORK_SA")
  tf_platform_sa_email = get_env("TF_PLATFORM_SA")

  state_bucket = get_env("TF_STATE_BUCKET")

  # Prefix for the existing terraform/shared state (read via terraform_remote_state).
  shared_state_prefix = "shared"
  
  # Toggle for DDoS protection. Options: "cloudflare", "cloud-armor", "none"
  ddos_protection = get_env("DDOS_PROTECTION")

  labels = {
    env  = "staging"
    team = "platform-engineering"
    managed-by = "terragrunt"
  }
}
