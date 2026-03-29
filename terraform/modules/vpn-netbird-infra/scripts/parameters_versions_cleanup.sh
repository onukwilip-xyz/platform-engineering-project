#!/bin/bash
set -euo pipefail

gcloud config set auth/impersonate_service_account "$IMPERSONATE_SA"

echo "Listing versions for parameter $PARAMETER_ID..."

versions=$(gcloud parametermanager parameters versions list \
    --parameter="$PARAMETER_ID" \
    --location=global \
    --project="$PROJECT_ID" \
    --format="value(name.basename())" 2>/dev/null || true)

echo "Versions found: $versions"

if [ -n "$versions" ]; then
    while IFS= read -r version; do
    echo "Deleting version: $version"
    gcloud parametermanager parameters versions delete "$version" \
        --parameter="$PARAMETER_ID" \
        --location=global \
        --project="$PROJECT_ID" \
        --quiet
    done <<< "$versions"
else
    echo "No versions found, skipping."
fi

gcloud config unset auth/impersonate_service_account