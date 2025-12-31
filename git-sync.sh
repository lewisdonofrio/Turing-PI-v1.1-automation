#!/bin/bash
# /opt/ansible-k3s-cluster/git-sync.sh
# Purpose: Sync all repo changes to GitHub in a safe, reproducible way.
# Notes:
#   - Must be run as builder user
#   - Ensures clean ownership and deterministic commit messages
#   - ASCII-only, nano-safe, no color, no magic

set -e

REPO="/opt/ansible-k3s-cluster"

# Ensure correct user
if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: Must run as builder user."
    exit 1
fi

# Ensure repo exists
if [ ! -d "$REPO/.git" ]; then
    echo "ERROR: Git repo not found at $REPO"
    exit 1
fi

cd "$REPO"

echo "=== GIT STATUS BEFORE SYNC ==="
git status

echo "=== STAGING ALL CHANGES ==="
git add -A

echo "=== COMMITTING ==="
git commit -m "Sync /opt changes: $(date -Iseconds)" || {
    echo "No changes to commit."
}

echo "=== PUSHING TO ORIGIN ==="
git push origin main

echo "=== DONE ==="
