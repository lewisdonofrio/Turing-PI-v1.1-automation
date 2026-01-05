#!/bin/sh
# /home/builder/scripts/run-k3s-kernel-config.sh
# Durable wrapper that copies the authoritative kernel-config-k3s-armv7.sh
# from ~/scripts into the kernel source tree and executes it there.
# Ensures reproducibility even if the kernel tree is deleted and recreated.

set -eu

KERNEL_DIR="/home/builder/src/kernel"
SCRIPT_NAME="kernel-config-k3s-armv7.sh"
SOURCE_SCRIPT="/home/builder/scripts/${SCRIPT_NAME}"
TARGET_SCRIPT="${KERNEL_DIR}/${SCRIPT_NAME}"

echo "=== k3s kernel config wrapper ==="

# Ensure kernel directory exists
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "ERROR: Kernel directory ${KERNEL_DIR} does not exist."
    echo "Extract or clone the kernel source before running this wrapper."
    exit 1
fi

# Ensure authoritative script exists in ~/scripts
if [ ! -f "${SOURCE_SCRIPT}" ]; then
    echo "ERROR: Authoritative script not found at ${SOURCE_SCRIPT}"
    echo "Place ${SCRIPT_NAME} in ~/scripts/ before running."
    exit 1
fi

# Always overwrite to avoid drift
echo "Copying authoritative ${SCRIPT_NAME} into kernel tree..."
cp "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"
chmod +x "${TARGET_SCRIPT}"

echo "Executing ${SCRIPT_NAME} inside kernel tree..."
cd "${KERNEL_DIR}"
exec "./${SCRIPT_NAME}"
