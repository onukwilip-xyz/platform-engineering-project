#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CI/CD Pipeline Setup Key  (no dedicated group)
#
# This block is guarded by CICD_SETUP_KEY_SECRET_ID — it is completely skipped
# when that variable is absent (i.e. for the routing-peer null_resource).
# ═══════════════════════════════════════════════════════════════════════════════

if [ -n "${CICD_SETUP_KEY_SECRET_ID:-}" ]; then

  CICD_SECRET_NAME=$(basename "$CICD_SETUP_KEY_SECRET_ID")
  CICD_PROJECT_CLEAN=$(basename "$PROJECT_ID")

  # ── Check Secret Manager first ──────────────────────────────────────────────
  CICD_GSM_EXIT=0
  CICD_GSM_OUT=$(gcloud secrets versions access latest \
    --secret="$CICD_SECRET_NAME" \
    --project="$CICD_PROJECT_CLEAN" \
    --impersonate-service-account="$IMPERSONATE_SA" 2>&1) || CICD_GSM_EXIT=$?

  if [ "$CICD_GSM_EXIT" -eq 0 ] && [ -n "$CICD_GSM_OUT" ]; then
    echo "CI/CD setup key already exists in Secret Manager, skipping."
  else
    echo "No CI/CD setup key in Secret Manager, proceeding..."

    # ── Fetch PAT ──────────────────────────────────────────────────────────────
    CICD_PAT_SECRET_NAME=$(basename "$PAT_SECRET_ID")
    CICD_PAT=$(gcloud secrets versions access latest \
      --secret="$CICD_PAT_SECRET_NAME" \
      --project="$CICD_PROJECT_CLEAN" \
      --impersonate-service-account="$IMPERSONATE_SA")

    # ── Check if a valid (non-revoked) key already exists in Netbird ───────────
    CICD_LIST_RESP=$(curl -s \
      "https://$NETBIRD_DOMAIN/api/setup-keys" \
      -H "Authorization: Token $CICD_PAT")
    echo "CI/CD setup key list response: $CICD_LIST_RESP"

    CICD_EXISTING_KEY=$(echo "$CICD_LIST_RESP" \
      | jq -r --arg name "$CICD_SETUP_KEY_NAME" \
          '(. // []) | .[] | select(.name == $name and .revoked == false) | .key // empty' \
      | head -1)

    if [ -n "$CICD_EXISTING_KEY" ]; then
      echo "CI/CD setup key '$CICD_SETUP_KEY_NAME' already exists in Netbird, storing to Secret Manager..."
      CICD_KEY="$CICD_EXISTING_KEY"
    else
      echo "Creating CI/CD setup key..."
      CICD_CREATE_HTTP=$(curl -s -o /tmp/create_cicd_key_resp.json -w "%{http_code}" \
        -X POST "https://$NETBIRD_DOMAIN/api/setup-keys" \
        -H "Authorization: Token $CICD_PAT" \
        -H "Content-Type: application/json" \
        -d "{
          \"name\": \"$CICD_SETUP_KEY_NAME\",
          \"type\": \"reusable\",
          \"expires_in\": 86400,
          \"ephemeral\": true,
          \"auto_groups\": [],
          \"usage_limit\": 0
        }")

      echo "Create CI/CD setup key HTTP status: $CICD_CREATE_HTTP"
      echo "Create CI/CD setup key response: $(cat /tmp/create_cicd_key_resp.json)"

      if [[ "$CICD_CREATE_HTTP" != "200" && "$CICD_CREATE_HTTP" != "201" ]]; then
        echo "CI/CD setup key creation failed with HTTP $CICD_CREATE_HTTP" && exit 1
      fi

      CICD_KEY=$(cat /tmp/create_cicd_key_resp.json | jq -r '.key')

      if [ -z "$CICD_KEY" ] || [ "$CICD_KEY" = "null" ]; then
        echo "Failed to parse CI/CD setup key from response." && exit 1
      fi

      echo "CI/CD setup key '$CICD_SETUP_KEY_NAME' created successfully."
    fi

    # ── Store in Secret Manager ────────────────────────────────────────────────
    echo "Storing CI/CD setup key in Secret Manager..."
    gcloud secrets versions add "$CICD_SECRET_NAME" \
      --data-file=<(echo -n "$CICD_KEY") \
      --project="$CICD_PROJECT_CLEAN" \
      --impersonate-service-account="$IMPERSONATE_SA"

    echo "CI/CD setup key stored in Secret Manager."
  fi

fi

# ── Check Secret Manager first — skip everything if key already stored ────

SETUP_KEY_SECRET_NAME=$(basename "$SETUP_KEY_SECRET_ID")
PROJECT_ID_CLEAN=$(basename "$PROJECT_ID")  # handle full resource path if passed

GSM_EXIT_CODE=0
GSM_OUTPUT=$(gcloud secrets versions access latest \
  --secret="$SETUP_KEY_SECRET_NAME" \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA" 2>&1) || GSM_EXIT_CODE=$?

if [ $GSM_EXIT_CODE -eq 0 ] && [ -n "$GSM_OUTPUT" ]; then
  echo "Setup key already exists in Secret Manager, skipping."
  exit 0
fi

echo "No setup key in Secret Manager, proceeding..."

# ── Fetch PAT and Group ID ────────────────────────────────────────────────

PAT_SECRET_NAME=$(basename "$PAT_SECRET_ID")
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_NAME" \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA")

GROUP_ID=$(gcloud parametermanager parameters versions render "v1" \
  --parameter="$PARAMETER_ID" \
  --location=global \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA" \
  --format="value(payload.data)" | base64 --decode)

echo "Using group ID: $GROUP_ID"

# ── Check if a valid (non-revoked) setup key already exists in Netbird ────

LIST_RESP=$(curl -s \
  "https://$NETBIRD_DOMAIN/api/setup-keys" \
  -H "Authorization: Token $PAT")
echo "Setup key list response: $LIST_RESP"

EXISTING_KEY=$(echo "$LIST_RESP" \
  | jq -r --arg name "$SETUP_KEY_NAME" \
      '(. // []) | .[] | select(.name == $name and .revoked == false) | .key // empty' \
  | head -1)

if [ -n "$EXISTING_KEY" ]; then
  echo "Setup key '$SETUP_KEY_NAME' already exists in Netbird, storing to Secret Manager..."
  KEY="$EXISTING_KEY"
else
  echo "Creating new setup key..."
  CREATE_HTTP=$(curl -s -o /tmp/create_key_resp.json -w "%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/setup-keys" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$SETUP_KEY_NAME\",
      \"type\": \"reusable\",
      \"expires_in\": 86400,
      \"auto_groups\": [\"$GROUP_ID\"],
      \"usage_limit\": 0
    }")

  echo "Create setup key HTTP status: $CREATE_HTTP"
  echo "Create setup key response: $(cat /tmp/create_key_resp.json)"

  if [[ "$CREATE_HTTP" != "200" && "$CREATE_HTTP" != "201" ]]; then
    echo "Setup key creation failed with HTTP $CREATE_HTTP" && exit 1
  fi

  KEY=$(cat /tmp/create_key_resp.json | jq -r '.key')

  if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
    echo "Failed to parse setup key from response." && exit 1
  fi

  echo "Setup key '$SETUP_KEY_NAME' created successfully."
fi

# ── Store in Secret Manager ───────────────────────────────────────────────

echo "Storing setup key in Secret Manager..."
gcloud secrets versions add "$SETUP_KEY_SECRET_NAME" \
  --data-file=<(echo -n "$KEY") \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA"

echo "Setup key stored in Secret Manager."