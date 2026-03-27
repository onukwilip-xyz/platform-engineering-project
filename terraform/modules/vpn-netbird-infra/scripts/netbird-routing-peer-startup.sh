#!/bin/bash
set -euo pipefail

# ── Terraform templatefile interpolations ─────────────────────────────────
export SETUP_KEY_SECRET_ID="${setup_key_secret_id}"
export NETBIRD_MANAGEMENT_URL="${netbird_management_url}"
export SETUP_KEY_SECRET_NAME=$(basename "$SETUP_KEY_SECRET_ID")

# ── Enable persistent IP forwarding ───────────────────────────────────────
echo "Enabling IP forwarding..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p

# ── Install dependencies ───────────────────────────────────────────────────
# gcloud is pre-installed on all GCE Debian images — no apt install needed
apt-get update -q
apt-get install -y curl jq

# ── Install Netbird client ─────────────────────────────────────────────────
if command -v netbird &> /dev/null; then
  echo "Netbird already installed, skipping."
else
  echo "Installing Netbird..."
  curl -fsSL https://pkgs.netbird.io/install.sh | bash
fi

# ── Get project ID via gcloud ─────────────────────────────────────────────
PROJECT_ID=$(gcloud config get-value core/project)

# ── Wait for setup key to be available in Secret Manager ─────────────────
echo "Waiting for setup key in Secret Manager..."
MAX_ATTEMPTS=40
for i in $(seq 1 $MAX_ATTEMPTS); do
  if gcloud secrets versions access latest \
      --secret="$SETUP_KEY_SECRET_NAME" \
      --project="$PROJECT_ID" > /dev/null 2>&1; then
    echo "Setup key available after attempt $i."
    break
  fi
  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "Timed out waiting for setup key." && exit 1
  fi
  echo "Attempt $i/$MAX_ATTEMPTS — waiting 30s..."
  sleep 30
done

# ── Fetch setup key from Secret Manager via gcloud ────────────────────────
echo "Fetching setup key..."
SETUP_KEY=$(gcloud secrets versions access latest \
  --secret="$SETUP_KEY_SECRET_NAME" \
  --project="$PROJECT_ID")

if [ -z "$SETUP_KEY" ] || [ "$SETUP_KEY" = "null" ]; then
  echo "Failed to fetch setup key from Secret Manager." && exit 1
fi

# ── Join the Netbird network (idempotent) ─────────────────────────────────
if netbird status 2>/dev/null | grep -q "Connected"; then
  echo "Netbird already connected, skipping join."
else
  echo "Joining Netbird network..."
  netbird up \
    --management-url "$NETBIRD_MANAGEMENT_URL" \
    --setup-key      "$SETUP_KEY"
fi

# ── Verify connection ──────────────────────────────────────────────────────
echo "Verifying Netbird connection..."
MAX_ATTEMPTS=12
for i in $(seq 1 $MAX_ATTEMPTS); do
  if netbird status | grep -q "Connected"; then
    echo "Netbird connected successfully after attempt $i."
    break
  fi
  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "Netbird failed to connect in time." && exit 1
  fi
  echo "Attempt $i/$MAX_ATTEMPTS — waiting 10s..."
  sleep 10
done

echo "Routing peer joined successfully." | tee /var/log/netbird-peer.log