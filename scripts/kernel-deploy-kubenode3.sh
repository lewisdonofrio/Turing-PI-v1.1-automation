#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  Pi-Aware Kernel Deploy for kubenode3
#  Safe for firmware, updates config.txt/cmdline.txt if needed.
#  Supports DRYRUN and LIVE modes.
# ==============================================================

MODE="${1:-DRYRUN}"

STAGE_BOOT="/home/alarm/stage-boot"
STAGE_MODS="/home/alarm/stage-mods"
BOOT="/boot"
MODDIR="/usr/lib/modules"
PRESET="/etc/mkinitcpio.d/linux-rpi.preset"

echo "=== kubenode3 Pi-aware kernel deploy ==="
echo "Mode: $MODE"
echo

# --------------------------------------------------------------
# Helper wrappers
# --------------------------------------------------------------
do() {
    if [[ "$MODE" == "DRYRUN" ]]; then
        echo "[DRYRUN] $*"
    else
        echo "[RUN] $*"
        eval "$@"
    fi
}

require_file() {
    local f="$1"
    if [[ ! -f "$f" ]]; then
        echo "ERROR: required file missing: $f"
        exit 1
    fi
}

# --------------------------------------------------------------
# Sanity: staging must exist
# --------------------------------------------------------------
require_file "$STAGE_BOOT/kernel7.img"
require_file "$STAGE_BOOT/kernelrelease.txt"

KREL=$(cat "$STAGE_BOOT/kernelrelease.txt")
echo "Kernelrelease from staging: $KREL"
echo

# --------------------------------------------------------------
# Sanity: firmware layer must exist (we do NOT create this)
# --------------------------------------------------------------
for f in start.elf fixup.dat config.txt cmdline.txt; do
    require_file "$BOOT/$f"
done
echo "Firmware layer present."
echo

# --------------------------------------------------------------
# 1) Install kernel image + DTBs + overlays
# --------------------------------------------------------------
echo "--- Installing kernel image + DTBs + overlays ---"

do "cp '$STAGE_BOOT/kernel7.img' '$BOOT/kernel7.img'"

# DTBs: copy only .dtb files, not overlays
do "cp '$STAGE_BOOT/'*.dtb '$BOOT/'"

# overlays
do "rsync -av '$STAGE_BOOT/overlays/' '$BOOT/overlays/'"

echo

# --------------------------------------------------------------
# 2) Install modules
# --------------------------------------------------------------
echo "--- Installing modules to $MODDIR/$KREL ---"

do "mkdir -p '$MODDIR/$KREL'"
do "rsync -av '$STAGE_MODS/' '$MODDIR/$KREL/'"

echo

# --------------------------------------------------------------
# 3) Fix mkinitcpio preset and rebuild initramfs
# --------------------------------------------------------------
echo "--- mkinitcpio preset + initramfs ---"

require_file "$PRESET"

# ensure ALL_kver points to our kernelrelease
if ! grep -q "ALL_kver=\"$KREL\"" "$PRESET"; then
    do "sed -i 's/^ALL_kver=.*/ALL_kver=\"$KREL\"/' '$PRESET'"
fi

echo "Preset now:"
grep '^ALL_kver' "$PRESET" || true
echo

# rebuild initramfs
do "mkinitcpio -p linux-rpi"

echo
do "ls -l '$BOOT/initramfs-linux.img'"
echo

# --------------------------------------------------------------
# 4) Validate and patch config.txt
# --------------------------------------------------------------
echo "--- Validating config.txt ---"

ensure_line() {
    local line="$1"
    if ! grep -qF "$line" "$BOOT/config.txt"; then
        do "printf '%s\n' '$line' >> '$BOOT/config.txt'"
    fi
}

ensure_line "kernel=kernel7.img"
ensure_line "device_tree=bcm2710-rpi-cm3.dtb"
ensure_line "initramfs initramfs-linux.img followkernel"

echo "config.txt after ensure:"
do "grep -E 'kernel=|device_tree|initramfs' '$BOOT/config.txt' || true"
echo

# --------------------------------------------------------------
# 5) Validate root UUID in cmdline.txt and fstab
# --------------------------------------------------------------
echo "--- Validating root UUID in cmdline.txt and fstab ---"

ROOT_UUID=$(blkid -s UUID -o value /dev/mmcblk0p2)

echo "Detected root UUID: $ROOT_UUID"
echo

# cmdline.txt
if ! grep -q "$ROOT_UUID" "$BOOT/cmdline.txt"; then
    # replace any root=UUID=... with correct one
    do "sed -i 's#root=UUID=[^ ]*#root=UUID=$ROOT_UUID#' '$BOOT/cmdline.txt'"
fi

echo "cmdline.txt now:"
do "cat '$BOOT/cmdline.txt'"
echo

# fstab
if [[ -f /etc/fstab ]]; then
    if ! grep -q "$ROOT_UUID" /etc/fstab; then
        # replace any existing root UUID line for / with correct one
        do "sed -i 's#UUID=[^ ]*  / #UUID=$ROOT_UUID  / #' /etc/fstab"
    fi
    echo "/etc/fstab now:"
    do "grep ' / ' /etc/fstab || true"
    echo
fi

echo "=== Deploy complete ($MODE) ==="
