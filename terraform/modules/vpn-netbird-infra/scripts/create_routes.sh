#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# Creates Netbird network routes for a list of CIDRs.
# Idempotent: skips routes that already exist (matched by CIDR).
#
# Required env vars:
#   PAT_SECRET_ID, PROJECT_ID, NETBIRD_DOMAIN,
#   PARAMETER_ID, ROUTES_JSON, IMPERSONATE_SA
#
# ROUTES_JSON format:
#   [{"cidr":"10.10.0.0/20","network_id":"vpc-subnet","description":"..."}, ...]
# ---------------------------------------------------------------

echo "Retrieving PAT from Secret Manager..."
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID" \
  --impersonate-service-account="$IMPERSONATE_SA")

echo "Retrieving Routing Peer group ID from Parameter Manager..."
GROUP_ID=$(gcloud parametermanager parameters versions render "v1" \
  --parameter="$PARAMETER_ID" \
  --location=global \
  --project="$PROJECT_ID" \
  --impersonate-service-account="$IMPERSONATE_SA" \
  --format="value(payload.data)" | base64 --decode)
echo "Routing Peer group ID: $GROUP_ID"

echo "Retrieving 'All' group ID from Netbird..."
ALL_GROUP_ID=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/groups" \
  -H "Authorization: Token $PAT" \
  | jq -r '.[] | select(.name == "All") | .id')
echo "All group ID: $ALL_GROUP_ID"

# Fetch existing routes once
echo "Fetching existing routes..."
EXISTING_ROUTES_HTTP=$(curl -s -o /tmp/existing_routes.json -w "%{http_code}" \
  "https://$NETBIRD_DOMAIN/api/routes" \
  -H "Authorization: Token $PAT")

echo "List routes HTTP status: $EXISTING_ROUTES_HTTP"

if [ "$EXISTING_ROUTES_HTTP" != "200" ]; then
  echo "ERROR: Failed to list routes (HTTP $EXISTING_ROUTES_HTTP)."
  echo "Response: $(cat /tmp/existing_routes.json)"
  exit 1
fi

EXISTING_ROUTES=$(cat /tmp/existing_routes.json)
ROUTE_COUNT=$(echo "$ROUTES_JSON" | jq length)

echo "Processing $ROUTE_COUNT route(s)..."

FAILED=0
SKIPPED=0
CREATED=0

for i in $(seq 0 $(( ROUTE_COUNT - 1 ))); do
  CIDR=$(echo "$ROUTES_JSON" | jq -r ".[$i].cidr")
  NETWORK_ID=$(echo "$ROUTES_JSON" | jq -r ".[$i].network_id")
  DESCRIPTION=$(echo "$ROUTES_JSON" | jq -r ".[$i].description")

  echo ""
  echo "--- Route $((i + 1))/$ROUTE_COUNT: $CIDR ($NETWORK_ID) ---"

  # Check if route already exists for this CIDR
  EXISTING_ID=$(echo "$EXISTING_ROUTES" | jq -r \
    --arg cidr "$CIDR" '.[]? | select(.network == $cidr) | .id // empty' 2>/dev/null | head -1 || true)

  if [ -n "$EXISTING_ID" ]; then
    echo "Route for $CIDR already exists (id: $EXISTING_ID), skipping."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "Creating route for $CIDR..."

  CREATE_HTTP=$(curl -s -o /tmp/create_route_resp.json -w "%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/routes" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"description\": \"$DESCRIPTION\",
      \"network_id\": \"$NETWORK_ID\",
      \"enabled\": true,
      \"network\": \"$CIDR\",
      \"masquerade\": true,
      \"metric\": 9999,
      \"peer_groups\": [\"$GROUP_ID\"],
      \"groups\": [\"$ALL_GROUP_ID\"]
    }")

  echo "Create route HTTP status: $CREATE_HTTP"
  echo "Create route response: $(cat /tmp/create_route_resp.json)"

  if [[ "$CREATE_HTTP" != "200" && "$CREATE_HTTP" != "201" ]]; then
    echo "WARNING: Failed to create route for $CIDR (HTTP $CREATE_HTTP)."
    FAILED=$((FAILED + 1))
    continue
  fi

  ROUTE_ID=$(cat /tmp/create_route_resp.json | jq -r '.id')
  echo "Route created for $CIDR (id: $ROUTE_ID)"
  CREATED=$((CREATED + 1))
done

echo ""
echo "============================================================"
echo " Route summary: $CREATED created, $SKIPPED skipped, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  echo " $FAILED route(s) failed — check the logs above."
fi
echo "============================================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

echo "Netbird route creation complete."