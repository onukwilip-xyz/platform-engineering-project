#!/bin/bash
set -euo pipefail

echo "Listing versions for parameter $PARAMETER_ID..."

versions=$(gcloud parametermanager parameters versions list \
    --parameter="$PARAMETER_ID" \
    --location=global \
    --project="$PROJECT_ID" \
    --impersonate-service-account="$IMPERSONATE_SA" \
    --format="value(name.basename())" 2>/dev/null || true)

echo "Versions found: $versions"

if [ -n "$versions" ]; then
    while IFS= read -r version; do
    echo "Deleting version: $version"
    gcloud parametermanager parameters versions delete "$version" \
        --parameter="$PARAMETER_ID" \
        --location=global \
        --project="$PROJECT_ID" \
        --impersonate-service-account="$IMPERSONATE_SA" \
        --quiet
    done <<< "$versions"
else
    echo "No versions found, skipping."
fi