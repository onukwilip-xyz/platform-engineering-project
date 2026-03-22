#!/bin/bash
set -euo pipefail

PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID")

GROUP_ID=$(gcloud parameter-manager parameters versions render "v1" \
  --parameter="$PARAMETER_ID" \
  --location=global \
  --project="$PROJECT_ID" \
  --format="value(payload.data)")

echo "Using group ID: $GROUP_ID"

# Check if setup key already exists and is not revoked
EXISTING=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/setup-keys" \
  -H "Authorization: Token $PAT" \
  | jq -r --arg name "$SETUP_KEY_NAME" \
    '.[] | select(.name == $name and .revoked == false) | .key // empty')

if [ -n "$EXISTING" ]; then
  echo "Setup key '$SETUP_KEY_NAME' already exists, skipping creation."
  KEY="$EXISTING"
else
  KEY=$(curl -sf -X POST \
    "https://$NETBIRD_DOMAIN/api/setup-keys" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$SETUP_KEY_NAME\",
      \"type\": \"reusable\",
      \"expires_in\": 86400,
      \"revoked\": false,
      \"auto_groups\": [\"$GROUP_ID\"],
      \"usage_limit\": 1
    }" | jq -r '.key')
  echo "Setup key '$SETUP_KEY_NAME' created."
fi

gcloud secrets versions add "$SETUP_KEY_SECRET_ID" \
  --data-file=<(echo -n "$KEY") \
  --project="$PROJECT_ID"

echo "Setup key stored in Secret Manager."