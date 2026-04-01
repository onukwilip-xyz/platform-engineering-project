#!/bin/bash
set -euo pipefail

echo "Polling for Netbird PAT in Secret Manager..."
echo "  Secret ID : $PAT_SECRET_ID"
echo "  Project   : $PROJECT_ID"
echo "  SA        : $IMPERSONATE_SA"

for i in $(seq 1 40); do
  # Run in if-condition so set -e doesn't kill the script on failure.
  # Capture both stdout and stderr so we can log the error.
  if error_output=$(gcloud secrets versions access latest \
      --secret="$PAT_SECRET_ID" \
      --project="$PROJECT_ID" \
      --impersonate-service-account="$IMPERSONATE_SA" 2>&1); then
    echo "PAT available after attempt $i."
    exit 0
  fi

  echo "Attempt $i/40 failed — $error_output"
  echo "Waiting 30s..."
  sleep 30
done

echo "Timed out waiting for PAT." && exit 1