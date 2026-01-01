#!/bin/bash
# =============================================================================
# /opt/ansible-k3s-cluster/git-sync.sh
# =============================================================================
# Purpose:
#   Canonical Git commit + push helper for ansible-k3s-cluster.
#   Ensures clean ownership, deterministic commit messages, and safe operation.
#
# Notes:
#   - Must be run as builder user.
#   - ASCII-only. Deterministic. Nano-safe. No color, no magic.
# =============================================================================

set -euo pipefail

REPO="/opt/ansible-k3s-cluster"
BRANCH="main"

# -----------------------------------------------------------------------------
# Ensure correct user
# -----------------------------------------------------------------------------
if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: Must run as builder user."
    exit 1
fi

# -----------------------------------------------------------------------------
# Ensure repo exists
# -----------------------------------------------------------------------------
if [ ! -d "$REPO/.git" ]; then
    echo "ERROR: Git repo not found at $REPO"
    exit 1
fi

cd "$REPO"

# -----------------------------------------------------------------------------
# Ownership sanity check
# -----------------------------------------------------------------------------
if find "$REPO" -not -user builder | grep -q .; then
    echo "ERROR: Repo contains files not owned by builder."
    echo "Run: sudo chown -R builder:builder $REPO"
    exit 1
fi

# -----------------------------------------------------------------------------
# Show status
# -----------------------------------------------------------------------------
echo "=== GIT STATUS BEFORE SYNC ==="
git status

# -----------------------------------------------------------------------------
# Stage all changes
# -----------------------------------------------------------------------------
echo "=== STAGING ALL CHANGES ==="
git add -A

# -----------------------------------------------------------------------------
# Commit message logic
# -----------------------------------------------------------------------------
if [ $# -gt 0 ]; then
    MSG="$*"
else
    MSG="Sync /opt changes: $(date -Iseconds)"
fi

echo "=== COMMITTING ==="
git commit -m "$MSG" || {
    echo "No changes to commit."
}

# -----------------------------------------------------------------------------
# Push to origin
# -----------------------------------------------------------------------------
echo "=== PUSHING TO ORIGIN ($BRANCH) ==="
git push origin "$BRANCH"

echo "=== DONE ==="
