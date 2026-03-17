terraform {
  backend "gcs" {
    # bucket = "pe-tf-state-bucket" # * Change this to the name of your GCS bucket for Terraform state
    prefix = "envs/prod"
  }
}