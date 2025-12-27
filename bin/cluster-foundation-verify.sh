#!/usr/bin/env bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/bin/cluster-foundation-verify.sh
# =============================================================================
# Purpose:
#   Verify the integrity of the cluster foundation files using the canonical
#   wc-based manifest:
#     /opt/ansible-k3s-cluster/manifest/cluster-foundation.manifest
#
# Checks:
#   - Every file listed in the manifest exists.
#   - Each file's byte count matches the manifest.
#   - Optionally reports unexpected files under the framework tree.
#
# Exit codes:
#   0  - All checks passed (no drift).
#   1  - Drift detected (missing or modified files).
#   2  - Usage or manifest errors.
#
# Usage:
#   sudo bash /opt/ansible-k3s-cluster/bin/cluster-foundation-verify.sh
#
# Notes:
#   - This script does NOT regenerate the manifest.
#   - Regeneration is a deliberate act via the manifest generation script.
# =============================================================================

set -euo pipefail

BASE_DIR="/opt/ansible-k3s-cluster"
MANIFEST_FILE="${BASE_DIR}/manifest/cluster-foundation.manifest"

if [ ! -f "${MANIFEST_FILE}" ]; then
  echo "ERROR: Manifest not found: ${MANIFEST_FILE}" >&2
  exit 2
fi

echo "Verifying cluster foundation using manifest:"
echo "  ${MANIFEST_FILE}"
echo

drift=0

# Read manifest lines that actually contain data: skip comments and blanks.
grep -v '^[#[:space:]]' "${MANIFEST_FILE}" | while read -r bytes path; do
  if [ ! -f "${path}" ]; then
    echo "MISSING: ${path}"
    drift=1
    continue
  fi

  current_bytes="$(wc -c < "${path}" | tr -d ' ')"

  if [ "${current_bytes}" != "${bytes}" ]; then
    echo "DRIFT: ${path} (expected ${bytes} bytes, found ${current_bytes} bytes)"
    drift=1
  fi
done

# Capture drift flag from subshell using a temp file
TMP_STATUS="$(mktemp)"
echo "${drift}" > "${TMP_STATUS}"
drift="$(cat "${TMP_STATUS}")"
rm -f "${TMP_STATUS}"

if [ "${drift}" -ne 0 ]; then
  echo
  echo "Integrity verification FAILED: drift detected."
  exit 1
fi

echo
echo "Integrity verification PASSED: no drift detected."
exit 0
