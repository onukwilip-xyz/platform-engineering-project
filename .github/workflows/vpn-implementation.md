Clean plan. Here's everything broken into sequential phases you can tick off one by one.

---

## Phase 1 — Terraform: Secret resource + IAM

Add to whichever module holds your other NetBird secrets (likely the same file as `netbird_routing_peer_setup_key`):

```hcl
# ── Secret resource ────────────────────────────────────────────────────────
resource "google_secret_manager_secret" "netbird_cicd_setup_key" {
  secret_id = var.netbird_cicd_setup_key_secret_id   # new variable, e.g. "netbird-cicd-setup-key"
  project   = var.project_id

  labels = merge(local.secret_labels, { usage = "netbird-cicd-setup-key" })

  replication {
    auto {}
  }
}

# ── Grant CI/CD SA read access to this secret ─────────────────────────────
# The pipeline authenticates as the CI/CD SA via WIF; it needs to read this
# secret to retrieve the key before calling netbird up.
resource "google_secret_manager_secret_iam_member" "cicd_sa_reads_netbird_cicd_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.netbird_cicd_setup_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cicd_sa_email}"   # your existing CI/CD SA variable
}
```

Add to `variables.tf`:
```hcl
variable "netbird_cicd_setup_key_secret_id" {
  description = "Secret Manager secret ID for the NetBird CI/CD setup key"
  type        = string
}
```

---

## Phase 2 — Script: Create CI/CD setup key

Same idempotency pattern as your routing peer script, with `ephemeral: true` and no group lookup:

```bash
#!/bin/bash
set -euo pipefail

# Required env vars:
#   NETBIRD_DOMAIN              – your self-hosted management domain (no scheme)
#   SETUP_KEY_NAME              – e.g. "github-actions-cicd"
#   SETUP_KEY_SECRET_ID         – full resource path or bare name of the GSM secret
#   PAT_SECRET_ID               – full resource path or bare name of the PAT secret
#   PROJECT_ID                  – GCP project ID or full resource path
#   IMPERSONATE_SA              – SA email to impersonate for gcloud calls

SETUP_KEY_SECRET_NAME=$(basename "$SETUP_KEY_SECRET_ID")
PAT_SECRET_NAME=$(basename "$PAT_SECRET_ID")
PROJECT_ID_CLEAN=$(basename "$PROJECT_ID")

# ── Skip entirely if key already exists in GSM ────────────────────────────
GSM_EXIT_CODE=0
GSM_OUTPUT=$(gcloud secrets versions access latest \
  --secret="$SETUP_KEY_SECRET_NAME" \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA" 2>&1) || GSM_EXIT_CODE=$?

if [ $GSM_EXIT_CODE -eq 0 ] && [ -n "$GSM_OUTPUT" ]; then
  echo "CI/CD setup key already exists in Secret Manager, skipping."
  exit 0
fi

echo "No CI/CD setup key found in Secret Manager, proceeding..."

# ── Fetch PAT ─────────────────────────────────────────────────────────────
PAT=$(gcloud secrets versions access latest \
  --secret="$PAT_SECRET_NAME" \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA")

# ── Check if key already exists in NetBird (non-revoked) ─────────────────
LIST_RESP=$(curl -s \
  "https://$NETBIRD_DOMAIN/api/setup-keys" \
  -H "Authorization: Token $PAT")
echo "Existing keys response: $LIST_RESP"

EXISTING_KEY=$(echo "$LIST_RESP" \
  | jq -r --arg name "$SETUP_KEY_NAME" \
      '(. // []) | .[] | select(.name == $name and .revoked == false) | .key // empty' \
  | head -1)

if [ -n "$EXISTING_KEY" ]; then
  echo "Key '$SETUP_KEY_NAME' already exists in NetBird, storing to GSM..."
  KEY="$EXISTING_KEY"
else
  echo "Creating new CI/CD setup key (ephemeral, no group)..."
  CREATE_HTTP=$(curl -s -o /tmp/cicd_key_resp.json -w "%{http_code}" \
    -X POST "https://$NETBIRD_DOMAIN/api/setup-keys" \
    -H "Authorization: Token $PAT" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\":        \"$SETUP_KEY_NAME\",
      \"type\":        \"reusable\",
      \"expires_in\":  86400,
      \"ephemeral\":   true,
      \"auto_groups\": [],
      \"usage_limit\": 0
    }")

  echo "HTTP status: $CREATE_HTTP"
  echo "Response:    $(cat /tmp/cicd_key_resp.json)"

  if [[ "$CREATE_HTTP" != "200" && "$CREATE_HTTP" != "201" ]]; then
    echo "Setup key creation failed with HTTP $CREATE_HTTP" && exit 1
  fi

  KEY=$(jq -r '.key' /tmp/cicd_key_resp.json)

  if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
    echo "Failed to parse key from response." && exit 1
  fi

  echo "CI/CD setup key created."
fi

# ── Store in Secret Manager ───────────────────────────────────────────────
echo "Storing CI/CD setup key in Secret Manager..."
gcloud secrets versions add "$SETUP_KEY_SECRET_NAME" \
  --data-file=<(echo -n "$KEY") \
  --project="$PROJECT_ID_CLEAN" \
  --impersonate-service-account="$IMPERSONATE_SA"

echo "Done — CI/CD setup key stored in Secret Manager."
```

---

## Phase 3 — One-time org variable

Add to your GitHub organisation variables (same place as `WIF_PROVIDER`, `CICD_SA_EMAIL` etc.):

| Variable | Value |
|---|---|
| `NETBIRD_MANAGEMENT_URL` | `https://your-netbird-domain.com:443` (full URL with scheme) |
| `NETBIRD_CICD_KEY_SECRET` | bare secret name, e.g. `netbird-cicd-setup-key` |

---

## Phase 4 — Pipeline: NetBird steps

Insert these four steps into the `staging` and `production` jobs only, positioned **after** the `Authenticate to GCP via WIF` step and **before** the `Write *.tfvars` step:

```yaml
      # ── NetBird: install ───────────────────────────────────────────────────
      - name: Install NetBird client
        env:
          NB_VERSION: "0.67.0"
        run: |
          if command -v netbird &>/dev/null; then
            echo "NetBird already installed: $(netbird version)"
          else
            echo "Installing NetBird v${NB_VERSION}..."
            curl -fsSL \
              "https://github.com/netbirdio/netbird/releases/download/v${NB_VERSION}/netbird_${NB_VERSION}_linux_amd64.tar.gz" \
              | sudo tar -xz -C /usr/local/bin netbird
            sudo chmod +x /usr/local/bin/netbird
            sudo netbird service install
            sudo netbird service start
            echo "Installed: $(netbird version)"
          fi

      # ── NetBird: retrieve key from GSM ─────────────────────────────────────
      # WIF auth has already run; the CI/CD SA has secretAccessor on this secret.
      - name: Retrieve NetBird CI/CD setup key
        id: nb
        run: |
          KEY=$(gcloud secrets versions access latest \
            --secret="${{ vars.NETBIRD_CICD_KEY_SECRET }}" \
            --project="${{ vars.TF_PROJECT }}")
          echo "::add-mask::$KEY"
          echo "key=$KEY" >> "$GITHUB_OUTPUT"

      # ── NetBird: join mesh ─────────────────────────────────────────────────
      - name: Connect to NetBird mesh
        env:
          SETUP_KEY: ${{ steps.nb.outputs.key }}
        run: |
          if sudo netbird status 2>/dev/null | grep -q "Management: Connected"; then
            echo "Already connected, skipping."
          else
            sudo netbird up \
              --management-url "${{ vars.NETBIRD_MANAGEMENT_URL }}" \
              --setup-key      "$SETUP_KEY" \
              --hostname       "gha-${{ github.run_id }}-${{ github.job }}"
          fi

      # ── NetBird: wait for routes ───────────────────────────────────────────
      # Prevents the DNS race condition where the tunnel is up but routing
      # isn't propagated yet when Terragrunt fires kubernetes/helm providers.
      - name: Wait for mesh to be ready
        run: |
          for i in $(seq 1 24); do
            STATUS=$(sudo netbird status 2>/dev/null || true)
            MGMT=$(echo "$STATUS" | grep "Management:" | awk '{print $2}')
            SIG=$(echo "$STATUS"  | grep "Signal:"     | awk '{print $2}')
            if [ "$MGMT" = "Connected" ] && [ "$SIG" = "Connected" ]; then
              echo "Ready after $((i * 5))s"
              sudo netbird status
              exit 0
            fi
            echo "  [${i}/24] Mgmt=${MGMT:-?} Sig=${SIG:-?}, retrying in 5s..."
            sleep 5
          done
          echo "ERROR: NetBird did not connect within 120s" && exit 1
```

---

## Execution order

```
1. terraform apply   → Phase 1 (creates the GSM secret + IAM binding)
2. bash script       → Phase 2 (creates key in NetBird, populates the GSM secret)
3. GH org settings   → Phase 3 (add NETBIRD_MANAGEMENT_URL + NETBIRD_CICD_KEY_SECRET)
4. pipeline YAML     → Phase 4 (update staging + production jobs)
5. test run          → trigger manually on a branch with staging only checked
```

The script in Phase 2 is safe to call from Terraform via a `null_resource` / `local-exec` provisioner if you want it wired into your existing automation, or run standalone — same as your other VPN scripts.