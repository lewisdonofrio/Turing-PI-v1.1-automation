#!/bin/bash
# cluster-sync.sh
# Purpose:
#   Sync builder-local scripts and playbooks into the canonical
#   /opt/ansible-k3s-cluster repository, then perform a git push.
#
# Notes:
#   - ASCII-only, nano-safe.
#   - Idempotent and future-maintainer-safe.
#   - Run as builder.

set -euo pipefail

REPO_DIR="/opt/ansible-k3s-cluster"
SCRIPTS_SRC="/home/builder/scripts"
PLAYBOOKS_SRC="/opt/ansible-k3s-cluster/playbooks"

echo "[cluster-sync] Starting sync at $(date)"

# ---------------------------------------------------------------------------
# 1. Sync builder scripts into repo
# ---------------------------------------------------------------------------
echo "[cluster-sync] Syncing builder scripts..."
rsync -av --delete \
    "${SCRIPTS_SRC}/" \
    "${REPO_DIR}/scripts/"

# ---------------------------------------------------------------------------
# 2. Ensure playbooks are present (optional: remove if not needed)
# ---------------------------------------------------------------------------
echo "[cluster-sync] Ensuring playbooks are present..."
rsync -av \
    "${PLAYBOOKS_SRC}/" \
    "${REPO_DIR}/playbooks/"

# ---------------------------------------------------------------------------
# 3. Perform git add/commit/push
# ---------------------------------------------------------------------------
echo "[cluster-sync] Performing git push..."
cd "${REPO_DIR}"

# Timestamped commit message
TS=$(date +"%Y-%m-%d %H:%M:%S")
git add -A
git commit -m "cluster-sync: ${TS}" || echo "[cluster-sync] No changes to commit."
git push origin main

echo "[cluster-sync] Sync + push complete."
