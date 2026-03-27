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
export NETBIRD_SERVICE_USER_NAME="${netbird_service_user_name}"
export NETBIRD_SERVICE_USER_TOKEN_NAME="${netbird_service_user_token_name}"
export ADMIN_EMAIL="${netbird_admin_email}"
export ADMIN_PASS_SECRET_ID="${netbird_admin_password_secret_id}"

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

curl -fsSL https://github.com/netbirdio/netbird/releases/download/v0.67.0/getting-started.sh \
  -o /opt/netbird/getting-started.sh

chmod +x /opt/netbird/getting-started.sh

# ── Skip installer if already run (docker-compose.yml is the indicator) ───
if [ -f /opt/netbird/docker-compose.yml ]; then
  echo "Netbird already installed, skipping installer."
else
  expect <<EXPECT
    set timeout 120
    spawn bash /opt/netbird/getting-started.sh
    expect "Enter choice*"    { send "0\r" }
    expect "Email address*"   { send "$LETSENCRYPT_EMAIL\r" }
    expect "Enable proxy?"    { send "N\r" }
    expect eof
EXPECT
fi

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

echo "About to generate PAT...."
echo "--- /opt/netbird contents ---"
ls -la /opt/netbird/
echo "--- config.yaml exists: $([ -f /opt/netbird/config.yaml ] && echo YES || echo NO) ---"
echo "--- management.env exists: $([ -f /opt/netbird/management.env ] && echo YES || echo NO) ---"

echo "Checking if Token exists in Secret Manager..."
echo "GSM Secret ID: $PAT_SECRET_ID"

PAT_SECRET_NAME=$(basename "$PAT_SECRET_ID")
echo "PAT_SECRET_NAME: $PAT_SECRET_NAME"

GSM_EXIT_CODE=0
GSM_CHECK_OUTPUT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_NAME" \
  --project="$PROJECT_ID" 2>&1) || GSM_EXIT_CODE=$?

echo "GSM check exit code: $GSM_EXIT_CODE"

if [ $GSM_EXIT_CODE -eq 0 ]; then
  echo "PAT already exists in Secret Manager, skipping generation."
  echo "Netbird server setup complete." | tee /var/log/netbird-setup.log
  exit 0
else
  echo "GSM Output: $GSM_CHECK_OUTPUT"
fi

# Retrieve the Admin password from Secret Manager and export it for use in the setup script

export ADMIN_PASS_SECRET_NAME=$(basename "$ADMIN_PASS_SECRET_ID")
echo "Fetching admin password from Secret Manager..."

GSM_ADMIN_PASS_EXIT_CODE=0
GSM_ADMIN_PASS_CHECK_OUTPUT=$(gcloud secrets versions access latest \
  --secret="$ADMIN_PASS_SECRET_NAME" \
  --project="$PROJECT_ID" 2>&1) || GSM_ADMIN_PASS_EXIT_CODE=$?

echo "GSM check exit code: $GSM_ADMIN_PASS_EXIT_CODE"

if [ $GSM_ADMIN_PASS_EXIT_CODE -eq 0 ]; then
  echo "Admin password retrieved from Secret Manager."
  export ADMIN_PASS="$GSM_ADMIN_PASS_CHECK_OUTPUT"
else
  echo "GSM Output: $GSM_ADMIN_PASS_CHECK_OUTPUT"
fi

# ── Step 1: Check if first-run setup is required ─────────────────────────
echo "Checking instance setup status..."
INSTANCE_RESP=$(curl -sf "https://$NETBIRD_DOMAIN/api/instance")
echo "Instance response: $INSTANCE_RESP"
SETUP_REQUIRED=$(echo "$INSTANCE_RESP" | jq -r '.setup_required')

if [ "$SETUP_REQUIRED" = "true" ]; then
  echo "Running first-time instance setup..."

  HTTP_CODE=$(curl -s -o /tmp/setup_resp.json -w "%%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/setup" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$ADMIN_EMAIL\", \"password\": \"$ADMIN_PASS\", \"name\": \"Admin\"}")

  echo "Setup HTTP status: $HTTP_CODE"
  echo "Setup response body: $(cat /tmp/setup_resp.json)"

  if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
    echo "Instance setup failed with HTTP $HTTP_CODE" && exit 1
  fi
else
  echo "Instance already set up, skipping."
fi

# ── Step 2: PKCE authorization_code flow to get bearer token ─────────────
echo "Generating PKCE values..."
CODE_VERIFIER=$(openssl rand -base64 64 | tr -d '=+/\n' | cut -c1-64)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" \
  | openssl dgst -sha256 -binary \
  | openssl base64 \
  | tr '+/' '-_' \
  | tr -d '=\n')
STATE=$(openssl rand -hex 16)
COOKIE_JAR=$(mktemp)
REDIRECT_URI="https://$NETBIRD_DOMAIN/nb-auth"

# Step 2a: Initiate auth — get Dex's internal login redirect
echo "Initiating OIDC auth flow..."
DEX_REDIRECT=$(curl -sc "$COOKIE_JAR" -o /dev/null -w "%%{redirect_url}" \
  "https://$NETBIRD_DOMAIN/oauth2/auth\
?response_type=code\
&client_id=netbird-dashboard\
&redirect_uri=https%3A%2F%2F$NETBIRD_DOMAIN%2Fnb-auth\
&state=$STATE\
&code_challenge=$CODE_CHALLENGE\
&code_challenge_method=S256\
&scope=openid+profile+email")
echo "Dex redirect: $DEX_REDIRECT"

# Step 2b: Fetch the Dex login page to extract the form's internal state
LOGIN_PAGE=$(curl -sc "$COOKIE_JAR" -b "$COOKIE_JAR" -L "$DEX_REDIRECT")
DEX_FORM_STATE=$(echo "$LOGIN_PAGE" | grep -oP '(?<=state=)[^"&]+' | head -1)
echo "Dex form state: $DEX_FORM_STATE"

if [ -z "$DEX_FORM_STATE" ]; then
  echo "Failed to extract Dex form state from login page." && exit 1
fi

# Step 2c: POST credentials to Dex login form
echo "Submitting login credentials..."
LOGIN_REDIRECT=$(curl -sb "$COOKIE_JAR" -b "$COOKIE_JAR" \
  -o /dev/null -w "%%{redirect_url}" \
  -X POST "https://$NETBIRD_DOMAIN/oauth2/auth/local/login?back=&state=$DEX_FORM_STATE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "login=$ADMIN_EMAIL" \
  --data-urlencode "password=$ADMIN_PASS")
echo "Login redirect: $LOGIN_REDIRECT"

AUTH_CODE=$(echo "$LOGIN_REDIRECT" | grep -oP '(?<=code=)[^&]+')
echo "Auth code: $AUTH_CODE"

if [ -z "$AUTH_CODE" ]; then
  echo "Failed to extract auth code — login may have failed (wrong credentials or unexpected redirect)." && exit 1
fi

# Step 2d: Exchange code + code_verifier for access token
echo "Exchanging auth code for bearer token..."
TOKEN_HTTP=$(curl -s -o /tmp/token_resp.json -w "%%{http_code}" \
  -X POST "https://$NETBIRD_DOMAIN/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "code=$AUTH_CODE" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "client_id=netbird-dashboard" \
  --data-urlencode "redirect_uri=$REDIRECT_URI" \
  --data-urlencode "code_verifier=$CODE_VERIFIER")

echo "Token HTTP status: $TOKEN_HTTP"
echo "Token response: $(cat /tmp/token_resp.json)"
rm -f "$COOKIE_JAR"

BEARER_TOKEN=$(cat /tmp/token_resp.json | jq -r '.access_token')

if [ -z "$BEARER_TOKEN" ] || [ "$BEARER_TOKEN" = "null" ]; then
  echo "Failed to obtain bearer token." && exit 1
fi

echo "Bearer token obtained successfully."

# ── Step 3: Create Service User (idempotent) ─────────────────────────────
echo "Checking for existing Terraform service user..."
EXISTING_USERS=$(curl -s \
  "https://$NETBIRD_DOMAIN/api/users?service_user=true" \
  -H "Authorization: Bearer $BEARER_TOKEN")
echo "Existing service users: $EXISTING_USERS"

SERVICE_USER_ID=$(echo "$EXISTING_USERS" \
  | jq -r --arg name "$NETBIRD_SERVICE_USER_NAME" \
      '.[] | select(.name == $name) | .id' | head -1)

if [ -n "$SERVICE_USER_ID" ] && [ "$SERVICE_USER_ID" != "null" ]; then
  echo "Terraform service user already exists: $SERVICE_USER_ID"
else
  echo "Creating Terraform service user..."
  SERVICE_USER_HTTP=$(curl -s -o /tmp/service_user_resp.json -w "%%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/users" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$NETBIRD_SERVICE_USER_NAME\",\"role\":\"admin\",\"auto_groups\":[],\"is_service_user\":true}")

  echo "Service User HTTP status: $SERVICE_USER_HTTP"
  echo "Service User response: $(cat /tmp/service_user_resp.json)"

  SERVICE_USER_ID=$(cat /tmp/service_user_resp.json | jq -r '.id')

  if [ -z "$SERVICE_USER_ID" ] || [ "$SERVICE_USER_ID" = "null" ]; then
    echo "Failed to create Service User." && exit 1
  fi
fi

echo "Service User ID: $SERVICE_USER_ID"

# ── Step 4: Create Token for Service User (idempotent) ───────────────────

echo "Checking for existing Terraform Token..."
EXISTING_TOKENS=$(curl -s \
  "https://$NETBIRD_DOMAIN/api/users/$SERVICE_USER_ID/tokens" \
  -H "Authorization: Bearer $BEARER_TOKEN")
echo "Existing tokens: $EXISTING_TOKENS"

EXISTING_TOKEN_ID=$(echo "$EXISTING_TOKENS" \
  | jq -r --arg name "$NETBIRD_SERVICE_USER_TOKEN_NAME" \
      '(. // []) | .[] | select(.name == $name) | .id' | head -1)

if [ -n "$EXISTING_TOKEN_ID" ] && [ "$EXISTING_TOKEN_ID" != "null" ]; then
  echo "'$NETBIRD_SERVICE_USER_TOKEN_NAME' already exists: $EXISTING_TOKEN_ID"
  echo "Note: plain_token is not retrievable for existing tokens — storing placeholder."
  # The PAT secret-already-exists check at the top of the script would have
  # caught a fully successful prior run. Reaching here means the token was
  # created but never stored. We can't recover the plain_token, so delete
  # the old one and create a fresh token.
  echo "Deleting all existing '$NETBIRD_SERVICE_USER_TOKEN_NAME' tokens..."
  ALL_TOKEN_IDS=$(echo "$EXISTING_TOKENS" \
    | jq -r --arg name "$NETBIRD_SERVICE_USER_TOKEN_NAME" \
        '(. // []) | .[] | select(.name == $name) | .id')

  for TOKEN_ID in $ALL_TOKEN_IDS; do
    echo "Deleting token: $TOKEN_ID"
    curl -s -X DELETE \
      "https://$NETBIRD_DOMAIN/api/users/$SERVICE_USER_ID/tokens/$TOKEN_ID" \
      -H "Authorization: Bearer $BEARER_TOKEN"
  done
fi

echo "Creating Personal Access Token..."
TOKEN_HTTP=$(curl -s -o /tmp/token_resp.json -w "%%{http_code}" \
  -X POST "https://$NETBIRD_DOMAIN/api/users/$SERVICE_USER_ID/tokens" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NETBIRD_SERVICE_USER_TOKEN_NAME\",\"expires_in\":1}")

echo "Token HTTP status: $TOKEN_HTTP"
echo "Token ID: $(cat /tmp/token_resp.json | jq -r '.personal_access_token.id')"

PLAIN_TOKEN=$(cat /tmp/token_resp.json | jq -r '.plain_token')

if [ -z "$PLAIN_TOKEN" ] || [ "$PLAIN_TOKEN" = "null" ]; then
  echo "Failed to create Personal Access Token." && exit 1
fi

# ── Step 5: Store PAT in Secret Manager ──────────────────────────────────
echo "Storing PAT in Secret Manager..."
gcloud secrets versions add "$PAT_SECRET_ID" \
  --data-file=<(echo -n "$PLAIN_TOKEN") \
  --project="$PROJECT_ID" \

echo "Netbird server setup complete." | tee /var/log/netbird-setup.log