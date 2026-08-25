# Terraform

```bash
export DDOS_PROTECTION="cloudflare"
export TF_PROJECT="pe-terraform-project-2"
export TF_PROJECT_NAME="terraform-project"
export ORG_ID="318156556060"

export TF_NETWORK_SA="tf-network"
export TF_PLATFORM_SA="tf-platform"

export TF_NETWORK_SA_EMAIL="$TF_NETWORK_SA@${TF_PROJECT}.iam.gserviceaccount.com"
export TF_PLATFORM_SA_EMAIL="$TF_PLATFORM_SA@${TF_PROJECT}.iam.gserviceaccount.com"

export BILLING_ACCOUNT_ID="017973-4DC748-6CE712"
export USER="prince@princeonuk.xyz"

export TF_STATE_BUCKET="pe-tf-state-bucket-2"
export LOCATION=us

export POOL_ID="github-actions-pool"
export PROVIDER_ID="github-oidc"
export GITHUB_ORG="onukwilip-xyz"
export GITHUB_REPO="${GITHUB_ORG}/platform-engineering-project"

export CICD_SA_SHARED="cicd-sa-shared"
export CICD_SA_STAGING="cicd-sa-staging"
export CICD_SA_PRODUCTION="cicd-sa-production"
export CICD_SA_GENERAL="cicd-sa-general"

export CICD_SA_SHARED_EMAIL="${CICD_SA_SHARED}@${TF_PROJECT}.iam.gserviceaccount.com"
export CICD_SA_STAGING_EMAIL="${CICD_SA_STAGING}@${TF_PROJECT}.iam.gserviceaccount.com"
export CICD_SA_PRODUCTION_EMAIL="${CICD_SA_PRODUCTION}@${TF_PROJECT}.iam.gserviceaccount.com"
export CICD_SA_GENERAL_EMAIL="${CICD_SA_GENERAL}@${TF_PROJECT}.iam.gserviceaccount.com"

export SECRET_SHARED="cicd-tfvars-shared"
export SECRET_STAGING="cicd-tfvars-staging"
export SECRET_PRODUCTION="cicd-tfvars-production"
export SECRET_DDOS="cicd-tfvars-ddos"

export CICD_SA_MICROSERVICES_STAGING="cicd-sa-ms-staging"
export CICD_SA_MICROSERVICES_PRODUCTION="cicd-sa-ms-production"

export CICD_SA_MICROSERVICES_STAGING_EMAIL="${CICD_SA_MICROSERVICES_STAGING}@${TF_PROJECT}.iam.gserviceaccount.com"
export CICD_SA_MICROSERVICES_PRODUCTION_EMAIL="${CICD_SA_MICROSERVICES_PRODUCTION}@${TF_PROJECT}.iam.gserviceaccount.com"

export GITHUB_REPO_MICROSERVICES="${GITHUB_ORG}/platform-engineering-microservices"

export ARTIFACT_REGISTRY_REGION="us-central1"
export ARTIFACT_REGISTRY_REPO="images"
```

Create Terraform project

```bash
gcloud projects create $TF_PROJECT --name="$TF_PROJECT_NAME" --organization=$ORG_ID
```

Export its Project Number
```bash
export PROJECT_NUMBER=$(gcloud projects describe "$TF_PROJECT" --format="value(projectNumber)")
```

Enable APIs in Terraform project

```bash
gcloud services enable cloudbilling.googleapis.com cloudresourcemanager.googleapis.com serviceusage.googleapis.com iam.googleapis.com storage.googleapis.com iamcredentials.googleapis.com orgpolicy.googleapis.com secretmanager.googleapis.com --project=$TF_PROJECT
```

Create Terraform Service Accounts

```bash
gcloud iam service-accounts create $TF_NETWORK_SA --project=$TF_PROJECT
gcloud iam service-accounts create $TF_PLATFORM_SA --project=$TF_PROJECT
```

Create the CI/CD SAs per environment

```bash
gcloud iam service-accounts create "$CICD_SA_SHARED" --project "$TF_PROJECT" --display-name "CI/CD Service Account (shared)"
gcloud iam service-accounts create "$CICD_SA_STAGING" --project "$TF_PROJECT" --display-name "CI/CD Service Account (staging)"
gcloud iam service-accounts create "$CICD_SA_PRODUCTION" --project "$TF_PROJECT" --display-name "CI/CD Service Account (production)"
gcloud iam service-accounts create "$CICD_SA_GENERAL" --project "$TF_PROJECT" --display-name "CI/CD Service Account (general)"
```

Grant organizational policies to the `tf-network` SA

```bash
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
gcloud billing projects link "$TF_PROJECT" --billing-account="$BILLING_ACCOUNT_ID"
```

Grant the TF Network SA permission to link the Billing account to host and service projects

```bash
gcloud beta billing accounts add-iam-policy-binding "$BILLING_ACCOUNT_ID" \
  --member="serviceAccount:$TF_NETWORK_SA_EMAIL" \
  --role="roles/billing.user"
```

Allow the gcloud authenticated user to impersonate the TF SAs

```bash
gcloud iam service-accounts add-iam-policy-binding "$TF_NETWORK_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="user:$USER" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_PLATFORM_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="user:$USER" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Grant the CI/CD SAs impersonation rights over the TF SAs

```bash
gcloud iam service-accounts add-iam-policy-binding "$TF_NETWORK_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_SHARED_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_PLATFORM_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_SHARED_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_NETWORK_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_STAGING_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_PLATFORM_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_STAGING_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_NETWORK_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_PRODUCTION_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_PLATFORM_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_PRODUCTION_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_NETWORK_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_GENERAL_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud iam service-accounts add-iam-policy-binding "$TF_PLATFORM_SA_EMAIL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_GENERAL_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Create the secrets for each environment TF vars

```bash
gcloud secrets create "$SECRET_SHARED" --project "$TF_PROJECT"
gcloud secrets create "$SECRET_STAGING" --project "$TF_PROJECT"
gcloud secrets create "$SECRET_PRODUCTION" --project "$TF_PROJECT"

# Special case
gcloud secrets create "$SECRET_DDOS" --project "$TF_PROJECT"
```

Grant the CI/CD SAs access to their respective secrets

```bash
gcloud secrets add-iam-policy-binding "$SECRET_SHARED" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_SHARED_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding "$SECRET_STAGING" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_STAGING_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding "$SECRET_PRODUCTION" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_PRODUCTION_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding "$SECRET_GENERAL" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_GENERAL_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

# Special cases
gcloud secrets add-iam-policy-binding "$SECRET_DDOS" \
  --project "$TF_PROJECT" \
  --member="serviceAccount:${CICD_SA_GENERAL_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"
```

Create the Workload Identity Pool

```bash
gcloud iam workload-identity-pools create "$POOL_ID" \
  --project "$TF_PROJECT" \
  --location "global" \
  --display-name "GitHub Actions Pool"
```

Create the GitHub OIDC Provider

```bash
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project "$TF_PROJECT" \
  --location "global" \
  --workload-identity-pool "$POOL_ID" \
  --display-name "GitHub OIDC" \
  --issuer-uri "https://token.actions.githubusercontent.com" \
  --attribute-mapping "google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.environment=assertion.environment" \
  --attribute-condition "assertion.repository_owner == '${GITHUB_ORG}'"
```

Allow the WIF pool to impersonate the CI/CD SAs (scoped per GitHub environment)

```bash
gcloud iam service-accounts add-iam-policy-binding "$CICD_SA_SHARED_EMAIL" \
  --project "$TF_PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.environment/shared" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding "$CICD_SA_STAGING_EMAIL" \
  --project "$TF_PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.environment/staging" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding "$CICD_SA_PRODUCTION_EMAIL" \
  --project "$TF_PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.environment/production" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding "$CICD_SA_GENERAL_EMAIL" \
  --project "$TF_PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.environment/general" \
  --role="roles/iam.workloadIdentityUser"
```

Retrieve values to configure as GitHub environment-level variables

```bash
echo "Org-level variable:"
echo "  WIF_PROVIDER = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo "  TF_PROJECT   = $TF_PROJECT"
echo "  NETBIRD_MANAGEMENT_URL = <your-netbird-url>"
echo ""
echo "shared environment:"
echo "  CICD_SA_EMAIL  = $CICD_SA_SHARED_EMAIL"
echo "  TF_VARS_SECRET = $SECRET_SHARED"
echo ""
echo "staging environment:"
echo "  CICD_SA_EMAIL  = $CICD_SA_STAGING_EMAIL"
echo "  TF_VARS_SECRET = $SECRET_STAGING"
echo ""
echo "production environment:"
echo "  CICD_SA_EMAIL  = $CICD_SA_PRODUCTION_EMAIL"
echo "  TF_VARS_SECRET = $SECRET_PRODUCTION"
echo ""
echo "general environment:"
echo "  CICD_SA_EMAIL  = $CICD_SA_GENERAL_EMAIL"
echo "  TF_VARS_SECRET = $SECRET_GENERAL"
```

Create the Storage Bucket for Terraform backend

```bash
gcloud storage buckets create "gs://$TF_STATE_BUCKET" \
  --project "$TF_PROJECT" \
  --location=$LOCATION \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://$TF_STATE_BUCKET" --versioning
```

Authenticate Terraform to Google Cloud

```bash
gcloud auth application-default login
gcloud auth login
```

Initialize Terraform

```bash
cd terraform/shared
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
```

Plan Terraform

```bash
terraform plan -var-file=".tfvars"
```

Apply Terraform

```bash
terraform apply -var-file=".tfvars"
```

---

## Microservices CI/CD Service Accounts

For the `platform-engineering-microservices` repo's pipelines (staging + production).

Requires `terraform/envs/staging/project` and `terraform/envs/staging/artifact-registry` to already be applied. `terraform/envs/production/` is empty — skip the production AR grant until it exists.

Create the SAs

```bash
gcloud iam service-accounts create "$CICD_SA_MICROSERVICES_STAGING" --project "$TF_PROJECT" --display-name "CI/CD Service Account (microservices - staging)"
gcloud iam service-accounts create "$CICD_SA_MICROSERVICES_PRODUCTION" --project "$TF_PROJECT" --display-name "CI/CD Service Account (microservices - production)"
```

Resolve the per-environment service project IDs (Terraform outputs, not created here)

```bash
export STAGING_SERVICE_PROJECT_ID=$(cd terraform/envs/staging/project && terragrunt output -raw service_project_id)

# once terraform/envs/production/project is applied:
# export PRODUCTION_SERVICE_PROJECT_ID=$(cd terraform/envs/production/project && terragrunt output -raw service_project_id)
```

Grant read + write access to the `images` Artifact Registry repo (`roles/artifactregistry.writer` covers both)

```bash
gcloud artifacts repositories add-iam-policy-binding "$ARTIFACT_REGISTRY_REPO" \
  --project "$STAGING_SERVICE_PROJECT_ID" \
  --location "$ARTIFACT_REGISTRY_REGION" \
  --member="serviceAccount:${CICD_SA_MICROSERVICES_STAGING_EMAIL}" \
  --role="roles/artifactregistry.writer"

# gcloud artifacts repositories add-iam-policy-binding "$ARTIFACT_REGISTRY_REPO" \
#   --project "$PRODUCTION_SERVICE_PROJECT_ID" \
#   --location "$ARTIFACT_REGISTRY_REGION" \
#   --member="serviceAccount:${CICD_SA_MICROSERVICES_PRODUCTION_EMAIL}" \
#   --role="roles/artifactregistry.writer"
```

Allow the WIF pool to impersonate the microservices CI/CD SAs (scoped per GitHub environment, same pool/provider as above)

```bash
gcloud iam service-accounts add-iam-policy-binding "$CICD_SA_MICROSERVICES_STAGING_EMAIL" \
  --project "$TF_PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.environment/staging" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding "$CICD_SA_MICROSERVICES_PRODUCTION_EMAIL" \
  --project "$TF_PROJECT" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.environment/production" \
  --role="roles/iam.workloadIdentityUser"
```

> Note: this binds on `attribute.environment` alone, same as the bindings above — any repo in the org with a `staging`/`production` GitHub Environment can impersonate these SAs. Was fine with one repo on the pool; with a second repo now sharing it, consider scoping these two bindings to `attribute.repository/${GITHUB_REPO_MICROSERVICES}` instead (mapping already exists on the provider, no provider change needed). Left loose here for consistency — flagging, not changing silently.

Retrieve values for GitHub environment-level variables (`platform-engineering-microservices` repo)

```bash
echo "WIF_PROVIDER (org-level, same as platform-engineering-project) = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo ""
echo "staging environment:"
echo "  CICD_SA_EMAIL = $CICD_SA_MICROSERVICES_STAGING_EMAIL"
echo ""
echo "production environment:"
echo "  CICD_SA_EMAIL = $CICD_SA_MICROSERVICES_PRODUCTION_EMAIL"
```

No `TF_VARS_SECRET` needed — these SAs never pull tfvars.