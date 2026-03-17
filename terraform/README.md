# Terraform

```bash
export TF_PROJECT="pe-terraform-project"
export TF_PROJECT_NAME="terraform-project"
export ORG_ID="256391743797"

export TF_NETWORK_SA="tf-network"
export TF_PLATFORM_SA="tf-platform"

export TF_NETWORK_SA_EMAIL="$TF_NETWORK_SA@${TF_PROJECT}.iam.gserviceaccount.com"
export TF_PLATFORM_SA_EMAIL="$TF_PLATFORM_SA@${TF_PROJECT}.iam.gserviceaccount.com"

export BILLING_ACCOUNT_ID="01E4F5-FFA2DF-D86AC5"
export USER="onukwilip@onukwilip.xyz"

export TF_STATE_BUCKET="pe-tf-state-bucket"
export LOCATION=us
```

Create Terraform project
```bash
gcloud projects create $TF_PROJECT --name="$TF_PROJECT_NAME" --organization=$ORG_ID
```

Enable APIs in Terraform project
```bash
gcloud services enable cloudbilling.googleapis.com cloudresourcemanager.googleapis.com serviceusage.googleapis.com iam.googleapis.com storage.googleapis.com iamcredentials.googleapis.com orgpolicy.googleapis.com --project=$TF_PROJECT
```

Create Terraform Service Accounts
```bash
export TF_NETWORK_SA="tf-network"
export TF_PLATFORM_SA="tf-platform"

gcloud iam service-accounts create $TF_NETWORK_SA --project=$TF_PROJECT
gcloud iam service-accounts create $TF_PLATFORM_SA --project=$TF_PROJECT
```

Grant organizational policies (for Shared VPC, creating projects, etc...) to the `tf-network` SA
```bash
export TF_NETWORK_SA_EMAIL="$TF_NETWORK_SA@${TF_PROJECT}.iam.gserviceaccount.com"
export TF_PLATFORM_SA_EMAIL="$TF_PLATFORM_SA@${TF_PROJECT}.iam.gserviceaccount.com"

gcloud organizations add-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${TF_NETWORK_SA_EMAIL}" \
  --role="roles/resourcemanager.projectCreator"

gcloud organizations add-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${TF_NETWORK_SA_EMAIL}" \
  --role="roles/resourcemanager.projectIamAdmin"

gcloud organizations add-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${TF_NETWORK_SA_EMAIL}" \
  --role="roles/compute.xpnAdmin"

gcloud organizations add-iam-policy-binding "$ORG_ID" \
  --member="serviceAccount:${TF_NETWORK_SA_EMAIL}" \
  --role="roles/orgpolicy.policyAdmin"
```

Enable Billing on the created project
```bash
export BILLING_ACCOUNT_ID="01E4F5-FFA2DF-D86AC5"

gcloud billing projects link "$TF_PROJECT" --billing-account="$BILLING_ACCOUNT_ID"
```

Grant the TF Network SA the permission to link the Billing account to the host and service projects
```bash
gcloud beta billing accounts add-iam-policy-binding "$BILLING_ACCOUNT_ID" \
  --member="serviceAccount:$TF_NETWORK_SA_EMAIL" \
  --role="roles/billing.user"
```

For manual run, allow the gcloud authenticated user impersonate the created TF Network and Platform SAs
```bash
export USER="onukwilip@onukwilip.xyz"

gcloud iam service-accounts add-iam-policy-binding "$TF_NETWORK_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="user:$USER" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_PLATFORM_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="user:$USER" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Create the Storage Bucket which will be used as the Terraform backend
```bash
export TF_STATE_BUCKET="pe-tf-state-bucket"
export LOCATION=us

gcloud storage buckets create "gs://$TF_STATE_BUCKET" \
  --project "$TF_PROJECT" \
  --location=$LOCATION \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://$TF_STATE_BUCKET" --versioning
```

Authenticate Terraform to Google Cloud
```bash
gcloud auth application-default login
```

Initialize Terraform
```bash
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
```

Refresh Terraform
```bash
terraform refresh -var-file=".tfvars"
```

Apply Terraform
```bash
terraform apply --auto-approve -var-file=".tfvars"
```