#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# Creates a Google Workspace identity provider in Netbird
# via the management API. Captures the redirect URI from the
# response and stores it in Parameter Manager for reference.
#
# Required env vars:
#   PROJECT_ID, NETBIRD_DOMAIN, PAT_SECRET_ID, IDP_NAME,
#   GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET,
#   REDIRECT_URI_PARAMETER_ID, IMPERSONATE_SA
# ---------------------------------------------------------------

# Retrieve PAT from Secret Manager
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_ID" \
  --project="$PROJECT_ID" \
  --impersonate-service-account="$IMPERSONATE_SA")

# Check if identity provider already exists
echo "Checking for existing identity provider '$IDP_NAME'..."

LIST_HTTP=$(curl -s -o /tmp/idp_list_resp.json -w "%{http_code}" \
  "https://$NETBIRD_DOMAIN/api/identity-providers" \
  -H "Authorization: Token $PAT")

echo "List identity providers HTTP status: $LIST_HTTP"
echo "List identity providers response: $(cat /tmp/idp_list_resp.json)"

if [ "$LIST_HTTP" != "200" ]; then
  echo "ERROR: Failed to list identity providers (HTTP $LIST_HTTP)."
  exit 1
fi

EXISTING=$(cat /tmp/idp_list_resp.json \
  | jq -r --arg name "$IDP_NAME" '.[]? | select(.name == $name) | .id // empty' 2>/dev/null || true)

if [ -n "$EXISTING" ]; then
  echo "Identity provider '$IDP_NAME' already exists (id: $EXISTING), updating..."

  UPDATE_HTTP=$(curl -s -o /tmp/idp_update_resp.json -w "%{http_code}" \
    -X PUT "https://$NETBIRD_DOMAIN/api/identity-providers/$EXISTING" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"type\": \"google\",
      \"name\": \"$IDP_NAME\",
      \"issuer\": \"https://accounts.google.com\",
      \"client_id\": \"$GOOGLE_OAUTH_CLIENT_ID\",
      \"client_secret\": \"$GOOGLE_OAUTH_CLIENT_SECRET\"
    }")

  echo "Update identity provider HTTP status: $UPDATE_HTTP"
  echo "Update identity provider response: $(cat /tmp/idp_update_resp.json)"

  if [[ "$UPDATE_HTTP" != "200" && "$UPDATE_HTTP" != "201" ]]; then
    echo "ERROR: Failed to update identity provider (HTTP $UPDATE_HTTP)."
    exit 1
  fi

  RESPONSE=$(cat /tmp/idp_update_resp.json)
  echo "Updated identity provider '$IDP_NAME'"
else
  echo "Creating identity provider '$IDP_NAME'..."

  CREATE_HTTP=$(curl -s -o /tmp/idp_create_resp.json -w "%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/identity-providers" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"type\": \"google\",
      \"name\": \"$IDP_NAME\",
      \"issuer\": \"https://accounts.google.com\",
      \"client_id\": \"$GOOGLE_OAUTH_CLIENT_ID\",
      \"client_secret\": \"$GOOGLE_OAUTH_CLIENT_SECRET\"
    }")

  echo "Create identity provider HTTP status: $CREATE_HTTP"
  echo "Create identity provider response: $(cat /tmp/idp_create_resp.json)"

  if [[ "$CREATE_HTTP" != "200" && "$CREATE_HTTP" != "201" ]]; then
    echo "ERROR: Failed to create identity provider (HTTP $CREATE_HTTP)."
    exit 1
  fi

  RESPONSE=$(cat /tmp/idp_create_resp.json)
  IDP_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

  if [ -z "$IDP_ID" ]; then
    echo "ERROR: Identity provider created but could not extract ID from response."
    exit 1
  fi

  echo "Created identity provider '$IDP_NAME' (id: $IDP_ID)"
fi

# Extract redirect URI from the response (try common field names)
REDIRECT_URI=$(echo "$RESPONSE" | jq -r '
  .redirect_uri // .redirectUri // .redirect_url // .redirectUrl // empty
' 2>/dev/null || true)

# Store the redirect URI in Parameter Manager for reference
if [ -n "$REDIRECT_URI" ]; then
  EXISTING_PARAM=$(gcloud parametermanager parameters versions list \
    --parameter="$REDIRECT_URI_PARAMETER_ID" \
    --location=global \
    --project="$PROJECT_ID" \
    --impersonate-service-account="$IMPERSONATE_SA" \
    --format="value(name)" 2>/dev/null | head -1 || true)

  if [ -n "$EXISTING_PARAM" ]; then
    echo "Redirect URI already stored in Parameter Manager, skipping write."
  else
    gcloud parametermanager parameters versions create "v1" \
      --parameter="$REDIRECT_URI_PARAMETER_ID" \
      --payload-data="$REDIRECT_URI" \
      --location=global \
      --project="$PROJECT_ID" \
      --impersonate-service-account="$IMPERSONATE_SA"
    echo "Redirect URI stored in Parameter Manager."
  fi

  PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" \
    --impersonate-service-account="$IMPERSONATE_SA" \
    --format="value(projectNumber)" 2>/dev/null || true)

  echo ""
  echo "============================================================"
  echo " ACTION REQUIRED (one-time manual step)"
  echo "============================================================"
  echo ""
  echo " Add this redirect URI to your Google OAuth client:"
  echo ""
  echo "   $REDIRECT_URI"
  echo ""
  echo " Steps:"
  echo "   1. Open Google Cloud Console > APIs & Services > Credentials"
  echo "      https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
  echo "   2. Click the 'NetBird' OAuth 2.0 Client ID"
  echo "   3. Under 'Authorized redirect URIs', click 'ADD URI'"
  echo "   4. Paste the URI above and click 'Save'"
  echo ""
  echo "============================================================"
else
  echo ""
  echo "NOTE: No redirect URI was returned in the API response."
  echo "Full response for reference:"
  echo "$RESPONSE" | jq .
fi

echo "Netbird identity provider setup complete."