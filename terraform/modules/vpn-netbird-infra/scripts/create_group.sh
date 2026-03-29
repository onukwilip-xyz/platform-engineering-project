#!/bin/bash
set -euo pipefail

gcloud config set auth/impersonate_service_account "$IMPERSONATE_SA"

PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID")

EXISTING=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/groups" \
  -H "Authorization: Token $PAT" \
  | jq -r --arg name "$GROUP_NAME" '.[] | select(.name == $name) | .id // empty')

if [ -n "$EXISTING" ]; then
  echo "Group '$GROUP_NAME' already exists: $EXISTING"
  GROUP_ID="$EXISTING"
else
  GROUP_ID=$(curl -sf -X POST \
    "https://$NETBIRD_DOMAIN/api/groups" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$GROUP_NAME\"}" \
    | jq -r '.id')
  echo "Created group '$GROUP_NAME': $GROUP_ID"
fi

# Check if parameter version already exists, add only if not
EXISTING_PARAM=$(gcloud parametermanager parameters versions list \
  --parameter="$PARAMETER_ID" \
  --location=global \
  --project="$PROJECT_ID" \
  --format="value(name)" 2>/dev/null | head -1 || true)

echo "Existing parameter version: $EXISTING_PARAM"

if [ -n "$EXISTING_PARAM" ]; then
  echo "Parameter version already exists, skipping write."
else
  gcloud parametermanager parameters versions create v1 \
    --parameter="$PARAMETER_ID" \
    --payload-data="$GROUP_ID" \
    --location=global \
    --project="$PROJECT_ID"
  echo "Group ID stored in Parameter Manager."
fi

gcloud config unset auth/impersonate_service_account