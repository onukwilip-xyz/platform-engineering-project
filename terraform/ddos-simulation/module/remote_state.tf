data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = var.shared_state_prefix
  }
}

data "terraform_remote_state" "gateway" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = var.gateway_state_prefix
  }
}
