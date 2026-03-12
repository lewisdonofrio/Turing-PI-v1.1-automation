#!/usr/bin/env bash
set -euo pipefail

KREL="6.18.1+"

BOOT_SRC="/home/builder/kernel-packages/worker7-1768275720/boot"
MOD_SRC="/home/builder/kernel-out/lib/modules/${KREL}"

STAGE="/home/builder/worker7-6.18.1+-staging"
mkdir -p "${STAGE}/boot" "${STAGE}/modules"

cp -av "${BOOT_SRC}/kernel7.img"         "${STAGE}/boot/kernel7.img"
cp -av "${BOOT_SRC}/initramfs-linux.img" "${STAGE}/boot/initramfs-linux.img"
cp -av "${BOOT_SRC}/bcm2710-rpi-cm3.dtb" "${STAGE}/boot/bcm2710-rpi-cm3.dtb"

cp -av "${MOD_SRC}" "${STAGE}/modules/${KREL}"

echo "Staged artifacts in: ${STAGE}"
