#!/bin/sh
set -eu

# /home/builder/scripts/git-push.sh
# Deterministic, 2AM-safe git add/commit/push wrapper.
# Always run from inside /opt/ansible-k3s-cluster.

REPO="/opt/ansible-k3s-cluster"

if [ ! -d "${REPO}/.git" ]; then
    echo "ERROR: ${REPO} is not a git repository."
    exit 1
fi

cd "${REPO}"

echo "=== Git status before commit ==="
git status

STAMP="$(date +%Y%m%d-%H%M%S)"
MSG="${1:-sync-${STAMP}}"

echo "=== Adding changes ==="
git add .

echo "=== Committing ==="
git commit -m "${MSG}" || {
    echo "No changes to commit."
    exit 0
}

echo "=== Pushing ==="
git push

echo "=== Git push complete ==="
