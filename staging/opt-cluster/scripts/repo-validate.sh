#!/bin/sh
set -eu

# =============================================================================
# File: /opt/cluster/scripts/repo-validate.sh
# =============================================================================
# Purpose:
#   Validate the /opt/cluster repository for internal consistency:
#     - required files exist
#     - permissions and executable bits are correct
#     - no tabs, no CRLF, no non-ASCII bytes in scripts and units
#
#   ASCII-only. Nano-safe. No tabs. No Unicode. No timestamps.
#   Safe to run at any time of day or night. Idempotent.
# =============================================================================

ROOT="/opt/cluster"

REQUIRED_FILES="
$ROOT/bootstrap/install-tmpfs-kernel-build.sh
$ROOT/scripts/builder-tmpfs-ensure
$ROOT/scripts/builder-preflight.sh
$ROOT/scripts/repo-validate.sh
$ROOT/systemd/tmp-kernel\x2dbuild.mount
"

fail() {
    echo "REPO VALIDATE FAILED: $*" >&2
    exit 1
}

info() {
    echo "REPO VALIDATE: $*"
}

# -----------------------------------------------------------------------------
# Check: required files exist
# -----------------------------------------------------------------------------
for f in $REQUIRED_FILES; do
    if [ ! -f "$f" ]; then
        fail "Missing required file: $f"
    fi
done

# -----------------------------------------------------------------------------
# Check: executable bits on scripts
# -----------------------------------------------------------------------------
SCRIPT_FILES="
$ROOT/bootstrap/install-tmpfs-kernel-build.sh
$ROOT/scripts/builder-tmpfs-ensure
$ROOT/scripts/builder-preflight.sh
$ROOT/scripts/repo-validate.sh
"

for f in $SCRIPT_FILES; do
    if [ ! -x "$f" ]; then
        fail "Expected executable script but not executable: $f"
    fi
done

# -----------------------------------------------------------------------------
# Check: no tabs, no CRLF, ASCII-only in scripts and units
# -----------------------------------------------------------------------------
TEXT_FILES="
$ROOT/bootstrap/install-tmpfs-kernel-build.sh
$ROOT/scripts/builder-tmpfs-ensure
$ROOT/scripts/builder-preflight.sh
$ROOT/scripts/repo-validate.sh
$ROOT/systemd/tmp-kernel\x2dbuild.mount
"

for f in $TEXT_FILES; do
    # Tabs
    if grep -q "$(printf '\t')" "$f"; then
        fail "Tab character found in file: $f"
    fi

    # CRLF
    if grep -q "$(printf '\r')" "$f"; then
        fail "Carriage return character found in file (possible CRLF): $f"
    fi

    # Non-ASCII
    if LC_ALL=C grep -n "[^ -~]" "$f" >/dev/null 2>&1; then
        fail "Non-ASCII byte found in file: $f"
    fi
done

info "All repo validation checks passed."
# -----------------------------------------------------------------------------
# End of file
# -----------------------------------------------------------------------------
