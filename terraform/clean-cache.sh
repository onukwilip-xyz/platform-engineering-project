#!/usr/bin/env bash
# clean-cache.sh — delete all .terragrunt-cache directories under envs/
#
# Usage:
#   ./clean-cache.sh              # cleans all envs
#   ./clean-cache.sh staging      # cleans envs/staging only
#   ./clean-cache.sh staging/gke  # cleans a specific unit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
SEARCH_ROOT="${SCRIPT_DIR}/envs/${TARGET}"

if [[ ! -d "${SEARCH_ROOT}" ]]; then
  echo "Error: directory not found: ${SEARCH_ROOT}" >&2
  exit 1
fi

find "${SEARCH_ROOT}" -type d -name ".terragrunt-cache" -exec rm -rf {} +
echo "Done — .terragrunt-cache directories removed from ${SEARCH_ROOT}"
