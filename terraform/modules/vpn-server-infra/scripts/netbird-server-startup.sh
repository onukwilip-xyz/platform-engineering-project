#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Install base dependencies ──────────────────────────────────────────────
apt-get update -q
apt-get install -y curl jq ca-certificates gnupg expect

# ── Install Docker (skip if already installed) ────────────────────────────
if ! command -v docker &> /dev/null; then
  echo "Docker not found, installing..."
  install -m 0755 -d /etc/apt/keyrings

  # ✅ --batch and --no-tty prevent gpg from trying to open /dev/tty
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --batch --no-tty --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -q
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
else
  echo "Docker already installed, skipping."
fi

systemctl enable docker && systemctl start docker

# ── Terraform templatefile interpolations ─────────────────────────────────
export NETBIRD_DOMAIN="${domain}"
export LETSENCRYPT_EMAIL="${letsencrypt_email}"
export NETBIRD_LETSENCRYPT_EMAIL="${letsencrypt_email}"  # explicit export matching setup.env key
export PAT_SECRET_ID="${pat_secret_id}"

# ── Get project ID via gcloud (uses instance service account automatically) 
PROJECT_ID=$(gcloud config get-value core/project)

# ── Run Netbird installer (non-interactively) ─────────────────────────────
mkdir -p /opt/netbird && cd /opt/netbird

# Write setup.env — the installer reads these automatically, no prompts needed
# for domain and email
cat > /opt/netbird/setup.env <<EOF
NETBIRD_DOMAIN=$NETBIRD_DOMAIN
NETBIRD_LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
EOF

curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started.sh \
  -o /opt/netbird/getting-started.sh

chmod +x /opt/netbird/getting-started.sh

expect <<EXPECT
  set timeout 120
  spawn bash /opt/netbird/getting-started.sh
  expect "Enter choice*"    { send "0\r" }
  expect "Email address*"   { send "$LETSENCRYPT_EMAIL\r" }
  expect "Enable proxy?"    { send "N\r" }
  expect eof
EXPECT

# ── Wait for Netbird management API to be healthy ─────────────────────────
echo "Waiting for Netbird to be healthy..."
MAX_ATTEMPTS=60
for i in $(seq 1 $MAX_ATTEMPTS); do
  if curl -sfk "https://$NETBIRD_DOMAIN/" -o /dev/null 2>&1; then
    echo "Netbird API is up after attempt $i."
    break
  fi
  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "Timed out waiting for Netbird." && exit 1
  fi
  echo "Attempt $i/$MAX_ATTEMPTS — waiting 15s..."
  sleep 15
done

# ── Extract initial admin credentials ─────────────────────────────────────
# The installer writes credentials to different files depending on version.
# Try both locations — new combined installer vs older Zitadel-based installer.
if [ -f /opt/netbird/config.yaml ]; then
  # New combined netbird-server installer (post ~v0.29)
  # Credentials are embedded in config.yaml
  ADMIN_USER=$(grep -A2 'initialUser' /opt/netbird/config.yaml \
    | grep 'email' | awk '{print $2}' | tr -d '"')
  ADMIN_PASS=$(grep -A2 'initialUser' /opt/netbird/config.yaml \
    | grep 'password' | awk '{print $2}' | tr -d '"')
elif [ -f /opt/netbird/management.env ]; then
  # Older Zitadel-based installer
  source /opt/netbird/management.env
  ADMIN_USER="$ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME"
  ADMIN_PASS="$ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD"
else
  echo "Could not find credentials file. Check /opt/netbird/ contents:" && ls /opt/netbird/
  exit 1
fi

if [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASS" ]; then
  echo "Failed to extract admin credentials. Dumping /opt/netbird/ for debugging:"
  ls -la /opt/netbird/
  exit 1
fi

echo "Admin user resolved: $ADMIN_USER"

# ── Authenticate → get session token ─────────────────────────────────────
echo "Authenticating with Netbird IdP..."
ADMIN_TOKEN=$(curl -sf -X POST "https://$NETBIRD_DOMAIN/auth/v1/users/me/_password" \
  -H "Content-Type: application/json" \
  -d "{\"loginName\": \"$ADMIN_USER\", \"password\": \"$ADMIN_PASS\"}" \
  | jq -r '.token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "Failed to obtain admin token." && exit 1
fi

# ── Create machine user + grant role ─────────────────────────────────────
echo "Creating Terraform service account in Netbird IdP..."
MACHINE_USER_ID=$(curl -sf -X POST \
  "https://$NETBIRD_DOMAIN/management/v1/users/machine" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userName":        "netbird-terraform-sa",
    "name":            "Netbird Terraform Service Account",
    "description":     "Used by Terraform to manage Netbird resources",
    "accessTokenType": "ACCESS_TOKEN_TYPE_BEARER"
  }' | jq -r '.userId')

if [ -z "$MACHINE_USER_ID" ] || [ "$MACHINE_USER_ID" = "null" ]; then
  echo "Failed to create machine user." && exit 1
fi

curl -sf -X POST "https://$NETBIRD_DOMAIN/management/v1/orgs/me/members" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"userId\": \"$MACHINE_USER_ID\", \"roles\": [\"ORG_OWNER\"]}" > /dev/null

# ── Generate PAT ──────────────────────────────────────────────────────────
echo "Generating PAT..."
NETBIRD_PAT=$(curl -sf -X POST \
  "https://$NETBIRD_DOMAIN/management/v1/users/$MACHINE_USER_ID/pats" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"expirationDate": "2099-01-01T00:00:00Z"}' \
  | jq -r '.token')

if [ -z "$NETBIRD_PAT" ] || [ "$NETBIRD_PAT" = "null" ]; then
  echo "Failed to generate PAT." && exit 1
fi

# ── Store PAT in Secret Manager ───────────────────────────────────────────
echo "Storing PAT in Secret Manager..."
gcloud secrets versions add "$PAT_SECRET_ID" \
  --data-file=<(echo -n "$NETBIRD_PAT") \
  --project="$PROJECT_ID"

echo "Netbird server setup complete." | tee /var/log/netbird-setup.log