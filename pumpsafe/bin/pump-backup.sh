#!/bin/sh
# filename: pump-backup.sh
# purpose: Backup pump-mode source and installed artifacts into a tarball
# usage: /opt/ansible-k3s-cluster/pumpsafe/bin/pump-backup.sh

set -eu

PUMPSAFE_ROOT="/opt/ansible-k3s-cluster/pumpsafe"
SITE_PKGS="/usr/lib/python3.13/site-packages"
BACKUP_ROOT="/var/backups/pumpsafe"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${BACKUP_ROOT}/pumpsafe-backup-${TS}.tar.gz"

echo "==> pump-backup.sh starting at $(date)"
echo "==> Pumpsafe root: ${PUMPSAFE_ROOT}"
echo "==> Backup root: ${BACKUP_ROOT}"

mkdir -p "${BACKUP_ROOT}"

if [ ! -d "${PUMPSAFE_ROOT}/distcc-pump-src" ]; then
    echo "ERROR: Source tree not found at ${PUMPSAFE_ROOT}/distcc-pump-src"
    exit 1
fi

INCLUDE_SERVER_DIR="${SITE_PKGS}/include_server"

if [ ! -d "${INCLUDE_SERVER_DIR}" ]; then
    echo "WARNING: include_server directory not found at ${INCLUDE_SERVER_DIR}"
fi

echo "==> Creating backup tarball: ${BACKUP_FILE}"

tar -czf "${BACKUP_FILE}" \
    -C "${PUMPSAFE_ROOT}" distcc-pump-src \
    -C "${PUMPSAFE_ROOT}" patches \
    -C "${PUMPSAFE_ROOT}" bin \
    -C "${PUMPSAFE_ROOT}" docs \
    -C "${PUMPSAFE_ROOT}" shims \
    -C "${SITE_PKGS}" include_server

echo "==> Backup complete."
echo "==> Backup file: ${BACKUP_FILE}"
echo "==> Add this file to your off-node backup rotation."
