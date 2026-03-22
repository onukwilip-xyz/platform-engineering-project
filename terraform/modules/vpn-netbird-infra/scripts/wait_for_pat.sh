#!/bin/bash
set -euo pipefail

echo "Polling for Netbird PAT in Secret Manager..."

for i in $(seq 1 40); do
  if gcloud secrets versions access latest \
      --secret="$PAT_SECRET_ID" \
      --project="$PROJECT_ID" > /dev/null 2>&1; then
    echo "PAT available after attempt $i."
    exit 0
  fi
  echo "Attempt $i/40 — waiting 30s..."
  sleep 30
done

echo "Timed out waiting for PAT." && exit 1