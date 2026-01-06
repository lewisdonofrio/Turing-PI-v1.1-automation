#!/bin/sh
set -eu

# /home/builder/scripts/sync-repo.sh
# Deterministic sync of all builder-owned scripts and custom system
# additions into the git repository at /opt/ansible-k3s-cluster/.
#
# Safe to run repeatedly. Never touches live system paths.

REPO="/opt/ansible-k3s-cluster"
STAGE="${REPO}/staging"

echo "=== Syncing scripts into repo staging ==="

# Ensure repo exists
if [ ! -d "${REPO}" ]; then
    echo "ERROR: Repo directory ${REPO} does not exist."
    exit 1
fi

# Clean staging
rm -rf "${STAGE}"
mkdir -p "${STAGE}"

# ---------------------------------------------------------------------
# 1. Home directory scripts
# ---------------------------------------------------------------------
mkdir -p "${STAGE}/home-scripts"
cp -a /home/builder/scripts/* "${STAGE}/home-scripts/"

# ---------------------------------------------------------------------
# 2. Builder environment setup
# ---------------------------------------------------------------------
cp -a /home/builder/builder-distcc-env-setup.sh "${STAGE}/"

# ---------------------------------------------------------------------
# 3. Custom /usr/local additions (safe only)
# ---------------------------------------------------------------------
mkdir -p "${STAGE}/usr-local-bin"
for f in /usr/local/bin/*; do
    [ -f "$f" ] && cp -a "$f" "${STAGE}/usr-local-bin/"
done

mkdir -p "${STAGE}/usr-local-sbin"
for f in /usr/local/sbin/*; do
    [ -f "$f" ] && cp -a "$f" "${STAGE}/usr-local-sbin/"
done

# ---------------------------------------------------------------------
# 4. Cluster doctrine under /opt
# ---------------------------------------------------------------------
mkdir -p "${STAGE}/opt-cluster"
if [ -d /opt/cluster ]; then
    cp -a /opt/cluster/* "${STAGE}/opt-cluster/"
fi

# ---------------------------------------------------------------------
# 5. Repo scripts (if any already exist)
# ---------------------------------------------------------------------
mkdir -p "${STAGE}/repo-scripts"
if [ -d "${REPO}/scripts" ]; then
    cp -a "${REPO}/scripts"/* "${STAGE}/repo-scripts/"
fi

echo "=== Sync complete ==="
echo "Staged content is in: ${STAGE}"
echo "You may now: cd ${REPO} && git add . && git commit -m 'sync before lock'"
