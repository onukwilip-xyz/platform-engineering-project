#!/bin/bash
set -euo pipefail

gcloud config set auth/impersonate_service_account "$IMPERSONATE_SA"

echo "Retrieving PAT from Secret Manager..."
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID")

echo "Retrieving Routing Peer group ID from Parameter Manager..."
GROUP_ID=$(gcloud parametermanager parameters versions render "v1" \
  --parameter="$PARAMETER_ID" \
  --location=global \
  --project="$PROJECT_ID" \
  --format="value(payload.data)" | base64 --decode)
echo "Routing Peer group ID: $GROUP_ID"

echo "Retrieving 'All' group ID from Netbird..."
ALL_GROUP_ID=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/groups" \
  -H "Authorization: Token $PAT" \
  | jq -r '.[] | select(.name == "All") | .id')
echo "All group ID: $ALL_GROUP_ID"

# Idempotency — skip if route already exists for this CIDR
echo "Checking for existing route for $VPC_CIDR..."
EXISTING=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/routes" \
  -H "Authorization: Token $PAT" \
  | jq -r --arg cidr "$VPC_CIDR" '.[] | select(.network == $cidr) | .id // empty')
echo "Existing route ID: $EXISTING"

if [ -n "$EXISTING" ]; then
  echo "Route for $VPC_CIDR already exists: $EXISTING"
  exit 0
fi

echo "No existing route for $VPC_CIDR, creating new route..."

CREATE_RESP=$(curl -s -o /tmp/create_route_resp.json -w "%{http_code}" \
  -X POST "https://$NETBIRD_DOMAIN/api/routes" \
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
  }")

echo "Create route status: $CREATE_RESP"
echo "Create route response: $(cat /tmp/create_route_resp.json)"

if [[ "$CREATE_RESP" != "200" && "$CREATE_RESP" != "201" ]]; then
  echo "Network Route creation failed with HTTP $CREATE_RESP" && exit 1
fi

ROUTE_ID=$(cat /tmp/create_route_resp.json | jq -r '.id')

echo "Route created for $VPC_CIDR: $ROUTE_ID"

gcloud config unset auth/impersonate_service_account