#!/bin/bash
set -euo pipefail

# Persistent IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Install Netbird
curl -fsSL https://pkgs.netbird.io/install.sh | bash

# Fetch setup key from Secret Manager using instance service account
ACCESS_TOKEN=$(curl -sf \
  -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | jq -r '.access_token')

PROJECT_ID=$(curl -sf \
  -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/project/project-id")

SETUP_KEY=$(curl -sf \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://secretmanager.googleapis.com/v1/projects/$PROJECT_ID/secrets/${setup_key_secret_id}/versions/latest:access" \
  | jq -r '.payload.data' | base64 -d)

# Join Netbird — peer auto-joins the routing-peers group via setup key auto_groups
netbird up \
  --management-url "${netbird_management_url}" \
  --setup-key "$SETUP_KEY"

# Netbird picks up the Network Route declared in Terraform automatically
# No manual `netbird routes add` needed — the route is pushed from Management

echo "Routing peer joined successfully." > /var/log/netbird-peer.log