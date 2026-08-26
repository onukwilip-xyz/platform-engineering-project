# Staging environment variables
# export SUBNET_KEY="gke-subnet"
# export DDOS_PROTECTION="cloudflare"
# export TF_STATE_BUCKET="pe-tf-state-bucket-2"

locals {
  env    = "staging"
  region = "us-central1"
  zone   = "us-central1-a"

  tf_network_sa_email  = get_env("TF_NETWORK_SA_EMAIL")
  tf_platform_sa_email = get_env("TF_PLATFORM_SA_EMAIL")

  state_bucket = get_env("TF_STATE_BUCKET")

  # Prefix for the existing terraform/shared state (read via terraform_remote_state).
  shared_state_prefix = "shared"

  # Key into the shared layer's subnet maps (subnet_names, subnet_self_links, ...)...
  # identifying this environment's subnet.
  subnet_key = get_env("SUBNET_KEY")

  # Toggle for DDoS protection. Options: "cloudflare", "cloud-armor", "none"
  ddos_protection = get_env("DDOS_PROTECTION")

  labels = {
    env  = "staging"
    team = "platform-engineering"
    managed-by = "terragrunt"
  }
}
