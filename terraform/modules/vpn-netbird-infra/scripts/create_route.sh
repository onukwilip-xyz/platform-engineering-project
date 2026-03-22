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

ALL_GROUP_ID=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/groups" \
  -H "Authorization: Token $PAT" \
  | jq -r '.[] | select(.name == "All") | .id')

# Idempotency — skip if route already exists for this CIDR
EXISTING=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/routes" \
  -H "Authorization: Token $PAT" \
  | jq -r --arg cidr "$VPC_CIDR" '.[] | select(.network == $cidr) | .id // empty')

if [ -n "$EXISTING" ]; then
  echo "Route for $VPC_CIDR already exists: $EXISTING"
  exit 0
fi

ROUTE_ID=$(curl -sf -X POST \
  "https://$NETBIRD_DOMAIN/api/routes" \
  -H "Authorization: Token $PAT" \
  -H "Content-Type: application/json" \
  -d "{
    \"description\": \"Route VPC subnet traffic through routing peer\",
    \"network_id\": \"vpc-internal-route\",
    \"enabled\": true,
    \"network\": \"$VPC_CIDR\",
    \"masquerade\": true,
    \"metric\": 9999,
    \"peer_groups\": [\"$GROUP_ID\"],
    \"groups\": [\"$ALL_GROUP_ID\"]
  }" | jq -r '.id')

echo "Route created for $VPC_CIDR: $ROUTE_ID"