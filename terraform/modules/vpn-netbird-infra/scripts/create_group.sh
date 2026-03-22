#!/bin/bash
set -euo pipefail

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
EXISTING_PARAM=$(gcloud parameter-manager parameters versions list \
  "$PARAMETER_ID" \
  --location=global \
  --project="$PROJECT_ID" \
  --format="value(name)" 2>/dev/null | head -1 || true)

if [ -n "$EXISTING_PARAM" ]; then
  echo "Parameter version already exists, skipping write."
else
  gcloud parameter-manager parameters versions create "v1" \
    --parameter="$PARAMETER_ID" \
    --parameter-data="$GROUP_ID" \
    --location=global \
    --project="$PROJECT_ID"
  echo "Group ID stored in Parameter Manager."
fi