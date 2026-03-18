#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -q
apt-get install -y docker.io docker-compose-plugin curl jq python3

systemctl enable docker && systemctl start docker

mkdir -p /opt/netbird && cd /opt/netbird

# ── Run Netbird installer ──────────────────────────────────────────────────
export NETBIRD_DOMAIN="${domain}"
export NETBIRD_LETSENCRYPT_EMAIL="${letsencrypt_email}"
export PAT_SECRET_ID="${pat_secret_id}"

curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/netbird_install.sh \
  | bash -s -- --domain "$NETBIRD_DOMAIN" --letsencrypt-email "$NETBIRD_LETSENCRYPT_EMAIL"

# ── Wait for Zitadel to be healthy ────────────────────────────────────────
echo "Waiting for Zitadel..."
until curl -sf "https://${domain}/auth/v1/health" > /dev/null 2>&1; do
  sleep 10
done
echo "Zitadel is up."

# ── Extract Zitadel initial admin credentials from installer output ───────
# The installer writes these to zitadel.env
source /opt/netbird/zitadel.env   # Provides ZITADEL_FIRSTINSTANCE vars

ZITADEL_DOMAIN="https://${domain}"
ADMIN_USER="$ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME"
ADMIN_PASS="$ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD"
ORG_ID="$ZITADEL_FIRSTINSTANCE_ORG_ID"

# ── Step 1: Authenticate as initial admin → get session token ────────────
SESSION_RESP=$(curl -sf -X POST "$ZITADEL_DOMAIN/auth/v1/users/me/_password" \
  -H "Content-Type: application/json" \
  -d "{\"loginName\": \"$ADMIN_USER\", \"password\": \"$ADMIN_PASS\"}")

ADMIN_TOKEN=$(echo "$SESSION_RESP" | jq -r '.token')

# ── Step 2: Create a Zitadel machine user (service account) ──────────────
MACHINE_RESP=$(curl -sf -X POST "$ZITADEL_DOMAIN/management/v1/users/machine" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userName": "netbird-terraform-sa",
    "name": "Netbird Terraform Service Account",
    "description": "Used by Terraform to manage Netbird resources",
    "accessTokenType": "ACCESS_TOKEN_TYPE_BEARER"
  }')

MACHINE_USER_ID=$(echo "$MACHINE_RESP" | jq -r '.userId')

# ── Step 3: Grant the machine user the Netbird IAM Admin role ─────────────
curl -sf -X POST "$ZITADEL_DOMAIN/management/v1/orgs/me/members" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$MACHINE_USER_ID\",
    \"roles\": [\"ORG_OWNER\"]
  }"

# ── Step 4: Generate a PAT for the machine user ───────────────────────────
PAT_RESP=$(curl -sf -X POST \
  "$ZITADEL_DOMAIN/management/v1/users/$MACHINE_USER_ID/pats" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "expirationDate": "2099-01-01T00:00:00Z"
  }')

NETBIRD_PAT=$(echo "$PAT_RESP" | jq -r '.token')

# ── Step 5: Store PAT in Secret Manager ──────────────────────────────────
METADATA_TOKEN=$(curl -sf \
  -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | jq -r '.access_token')

PROJECT_ID=$(curl -sf \
  -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/project/project-id")

curl -sf -X POST \
  "https://secretmanager.googleapis.com/v1/projects/$PROJECT_ID/secrets/${PAT_SECRET_ID}/versions:add" \
  -H "Authorization: Bearer $METADATA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"payload\": {\"data\": \"$(echo -n "$NETBIRD_PAT" | base64 -w0)\"}}"

echo "PAT generated and stored in Secret Manager." > /var/log/netbird-setup.log