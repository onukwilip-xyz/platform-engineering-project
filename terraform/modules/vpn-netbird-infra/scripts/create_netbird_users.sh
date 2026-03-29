#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# Sends user invitations in Netbird via the invites API.
# Idempotent: skips users that already exist or have a pending invite.
#
# Required env vars:
#   PROJECT_ID, NETBIRD_DOMAIN, PAT_SECRET_ID,
#   USERS_JSON, IMPERSONATE_SA
#
# USERS_JSON format:
#   [{"name":"Alice","email":"alice@example.com","role":"admin"}, ...]
# ---------------------------------------------------------------

gcloud config set auth/impersonate_service_account "$IMPERSONATE_SA"

# Retrieve PAT from Secret Manager
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID")

# Fetch existing users
echo "Fetching existing users..."

USERS_LIST_HTTP=$(curl -s -o /tmp/users_list_resp.json -w "%{http_code}" \
  "https://$NETBIRD_DOMAIN/api/users?service_user=false" \
  -H "Authorization: Token $PAT")

echo "List users HTTP status: $USERS_LIST_HTTP"

if [ "$USERS_LIST_HTTP" != "200" ]; then
  echo "ERROR: Failed to list users (HTTP $USERS_LIST_HTTP)."
  echo "Response: $(cat /tmp/users_list_resp.json)"
  gcloud config unset auth/impersonate_service_account
  exit 1
fi

EXISTING_USERS=$(cat /tmp/users_list_resp.json)

# Fetch existing invites
echo "Fetching existing invites..."

INVITES_LIST_HTTP=$(curl -s -o /tmp/invites_list_resp.json -w "%{http_code}" \
  "https://$NETBIRD_DOMAIN/api/users/invites" \
  -H "Authorization: Token $PAT")

echo "List invites HTTP status: $INVITES_LIST_HTTP"

EXISTING_INVITES="[]"
if [ "$INVITES_LIST_HTTP" = "200" ]; then
  EXISTING_INVITES=$(cat /tmp/invites_list_resp.json)
else
  echo "WARNING: Could not list existing invites (HTTP $INVITES_LIST_HTTP). Will attempt to create all invites."
  echo "Response: $(cat /tmp/invites_list_resp.json)"
fi

USER_COUNT=$(echo "$USERS_JSON" | jq length)
echo "Processing $USER_COUNT user invite(s)..."

FAILED=0
SKIPPED=0
CREATED=0

for i in $(seq 0 $(( USER_COUNT - 1 ))); do
  NAME=$(echo "$USERS_JSON" | jq -r ".[$i].name")
  EMAIL=$(echo "$USERS_JSON" | jq -r ".[$i].email")
  ROLE=$(echo "$USERS_JSON" | jq -r ".[$i].role")

  echo ""
  echo "--- User $((i + 1))/$USER_COUNT: $NAME <$EMAIL> (role: $ROLE) ---"

  # Check if user already exists (match by email)
  EXISTING_USER_ID=$(echo "$EXISTING_USERS" | jq -r \
    --arg email "$EMAIL" '.[]? | select(.email == $email) | .id // empty' 2>/dev/null | head -1 || true)

  if [ -n "$EXISTING_USER_ID" ]; then
    echo "User '$EMAIL' already exists (id: $EXISTING_USER_ID), skipping."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check if a non-expired invite already exists (match by email)
  EXISTING_INVITE_ID=$(echo "$EXISTING_INVITES" | jq -r \
    --arg email "$EMAIL" '.[]? | select(.email == $email and .expired == false) | .id // empty' 2>/dev/null | head -1 || true)

  if [ -n "$EXISTING_INVITE_ID" ]; then
    echo "Pending invite for '$EMAIL' already exists (id: $EXISTING_INVITE_ID), skipping."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "Sending invite to '$NAME' <$EMAIL>..."

  INVITE_HTTP=$(curl -s -o /tmp/invite_create_resp.json -w "%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/users/invites" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$NAME\",
      \"email\": \"$EMAIL\",
      \"role\": \"$ROLE\",
      \"auto_groups\": []
    }")

  echo "Create invite HTTP status: $INVITE_HTTP"
  echo "Create invite response: $(cat /tmp/invite_create_resp.json)"

  if [[ "$INVITE_HTTP" != "200" && "$INVITE_HTTP" != "201" ]]; then
    echo "WARNING: Failed to send invite to '$EMAIL' (HTTP $INVITE_HTTP)."
    FAILED=$((FAILED + 1))
    continue
  fi

  INVITE_ID=$(cat /tmp/invite_create_resp.json | jq -r '.id // empty')
  echo "Invite sent to '$NAME' <$EMAIL> (invite id: $INVITE_ID)"
  CREATED=$((CREATED + 1))
done

echo ""
echo "============================================================"
echo " Invite summary: $CREATED created, $SKIPPED skipped, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  echo " $FAILED invite(s) failed — check the logs above."
fi
echo "============================================================"

gcloud config unset auth/impersonate_service_account

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

echo "Netbird user invites complete."