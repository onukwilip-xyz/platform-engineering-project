#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# Creates a Netbird nameserver group that forwards DNS queries
# for INTERNAL_DNS_DOMAIN to the VPC's Cloud DNS inbound resolver.
#
# The resolver IP is the DNS_RESOLVER-purpose address allocated by
# GCP when the vpc inbound DNS policy is enabled. This address
# accepts queries from VPN/Interconnect clients — unlike the
# metadata-server DNS (169.254.169.254) which only works from
# inside the VPC.
#
# Idempotent: skips creation if a group for that domain already exists.
#
# Required env vars:
#   PAT_SECRET_ID, PROJECT_ID, NETBIRD_DOMAIN,
#   SUBNETWORK_NAME, REGION, INTERNAL_DNS_DOMAIN, IMPERSONATE_SA
# ---------------------------------------------------------------

echo "Looking up Cloud DNS inbound resolver IP for subnet '$SUBNETWORK_NAME' in '$REGION'..."
DNS_RESOLVER_IP=$(gcloud compute addresses list \
  --filter="purpose=DNS_RESOLVER AND subnetwork:${SUBNETWORK_NAME}" \
  --format="value(address)" \
  --regions="${REGION}" \
  --project="${PROJECT_ID}" \
  --impersonate-service-account="${IMPERSONATE_SA}" \
  | head -1)

if [ -z "$DNS_RESOLVER_IP" ]; then
  echo "ERROR: No DNS_RESOLVER address found for subnet '$SUBNETWORK_NAME'."
  echo "Make sure the Cloud DNS inbound forwarding policy has been applied to the VPC first."
  exit 1
fi
echo "DNS inbound resolver IP: $DNS_RESOLVER_IP"

echo "Retrieving PAT from Secret Manager..."
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID" \
  --impersonate-service-account="$IMPERSONATE_SA")

echo "Retrieving 'All' group ID from Netbird..."
ALL_GROUP_ID=$(curl -sf \
  "https://$NETBIRD_DOMAIN/api/groups" \
  -H "Authorization: Token $PAT" \
  | jq -r '.[] | select(.name == "All") | .id')
echo "All group ID: $ALL_GROUP_ID"

# Fetch existing nameserver groups
echo "Fetching existing nameserver groups..."
EXISTING_HTTP=$(curl -s -o /tmp/existing_ns.json -w "%{http_code}" \
  "https://$NETBIRD_DOMAIN/api/dns/nameservers" \
  -H "Authorization: Token $PAT")

echo "List nameservers HTTP status: $EXISTING_HTTP"

if [ "$EXISTING_HTTP" != "200" ]; then
  echo "ERROR: Failed to list nameserver groups (HTTP $EXISTING_HTTP)."
  echo "Response: $(cat /tmp/existing_ns.json)"
  exit 1
fi

# Check whether a nameserver group already covers our domain (idempotent)
EXISTING_ID=$(cat /tmp/existing_ns.json | jq -r \
  --arg domain "$INTERNAL_DNS_DOMAIN" \
  '[.[]? | select(.domains[]? == $domain)] | first | .id // empty' 2>/dev/null || true)

if [ -n "$EXISTING_ID" ]; then
  echo "Nameserver group for '$INTERNAL_DNS_DOMAIN' already exists (id: $EXISTING_ID)."
  # Check if the resolver IP needs updating
  EXISTING_IP=$(cat /tmp/existing_ns.json | jq -r \
    --arg domain "$INTERNAL_DNS_DOMAIN" \
    '[.[]? | select(.domains[]? == $domain)] | first | .nameservers[0].ip // empty' 2>/dev/null || true)

  if [ "$EXISTING_IP" = "$DNS_RESOLVER_IP" ]; then
    echo "Resolver IP is already correct ($DNS_RESOLVER_IP), skipping."
    exit 0
  fi

  echo "Resolver IP mismatch (current: $EXISTING_IP, expected: $DNS_RESOLVER_IP). Deleting stale entry..."
  DELETE_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE "https://$NETBIRD_DOMAIN/api/dns/nameservers/$EXISTING_ID" \
    -H "Authorization: Token $PAT")
  echo "Delete HTTP status: $DELETE_HTTP"
  if [[ "$DELETE_HTTP" != "200" && "$DELETE_HTTP" != "204" ]]; then
    echo "ERROR: Failed to delete stale nameserver group (HTTP $DELETE_HTTP)."
    exit 1
  fi
fi

echo "Creating nameserver group for '$INTERNAL_DNS_DOMAIN' -> $DNS_RESOLVER_IP ..."

CREATE_HTTP=$(curl -s -o /tmp/create_ns_resp.json -w "%{http_code}" \
  -X POST "https://$NETBIRD_DOMAIN/api/dns/nameservers" \
  -H "Authorization: Token $PAT" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"gcp-internal\",
    \"description\": \"Routes $INTERNAL_DNS_DOMAIN to GCP Cloud DNS inbound resolver ($DNS_RESOLVER_IP)\",
    \"nameservers\": [{\"ip\": \"$DNS_RESOLVER_IP\", \"ns_type\": \"udp\", \"port\": 53}],
    \"groups\": [\"$ALL_GROUP_ID\"],
    \"primary\": false,
    \"domains\": [\"$INTERNAL_DNS_DOMAIN\"],
    \"enabled\": true
  }")

echo "Create nameserver HTTP status: $CREATE_HTTP"
echo "Create nameserver response: $(cat /tmp/create_ns_resp.json)"

if [[ "$CREATE_HTTP" != "200" && "$CREATE_HTTP" != "201" ]]; then
  echo "ERROR: Failed to create nameserver group (HTTP $CREATE_HTTP)."
  exit 1
fi

NS_ID=$(cat /tmp/create_ns_resp.json | jq -r '.id')
echo "Nameserver group created (id: $NS_ID)"
echo "Netbird nameserver group creation complete."