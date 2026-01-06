#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-install-worker7.sh
#
#  Purpose:
#    Install the newly built kernel on worker7 using the synchronized
#    artifacts. This script installs the Arch Linux kernel packages,
#    updates /boot, verifies the installation, and reboots worker7.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Assumes kernel-clone-to-worker7.sh has already been run.
# =====================================================================

set -euo pipefail

TARGET="kubenode7.home.lab"

# ---------------------------------------------------------------------
#  Environment validation
# ---------------------------------------------------------------------

if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: Must run as builder user"
    exit 1
fi

if [ "$(hostname)" != "kubenode1" ]; then
    echo "ERROR: Must run on kubenode1"
    exit 1
fi

echo "Preparing to install kernel on $TARGET"
echo

# ---------------------------------------------------------------------
#  Verify target is reachable
# ---------------------------------------------------------------------

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

# ---------------------------------------------------------------------
#  Install kernel packages
# ---------------------------------------------------------------------

echo "Installing kernel packages on worker7..."

ssh "$TARGET" "sudo pacman -U --noconfirm /home/builder/pkgout/*.pkg.tar.zst"

# ---------------------------------------------------------------------
#  Verify kernel files exist
# ---------------------------------------------------------------------

echo "Verifying kernel installation..."

ssh "$TARGET" "test -f /boot/kernel7.img || echo 'WARNING: kernel7.img missing'"
ssh "$TARGET" "test -d /usr/lib/modules || echo 'WARNING: modules directory missing'"

# ---------------------------------------------------------------------
#  Confirm reboot
# ---------------------------------------------------------------------

echo
echo "Kernel installation complete."
echo "Reboot worker7 to test the new kernel? (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "Aborting before reboot."
    exit 0
fi

# ---------------------------------------------------------------------
#  Reboot worker7
# ---------------------------------------------------------------------

echo "Rebooting worker7..."
ssh "$TARGET" "sudo reboot"

echo "Worker7 is rebooting."
echo "Use kernel-health-worker7.sh to verify the new kernel after it comes back online."
