#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
PKG_REPO="${HOME}/src/PKGBUILDs"
PKG_PATH="${PKG_REPO}/core/linux-rpi"
BUILD_ROOT="${HOME}/kernel-builds"
VERSION="6.18.7-2-rpi"
KVER="6.18.7"

echo "=== Kernel Source Fetch & Prep ==="
echo "Target version: ${VERSION}"
echo

# --- Clone PKGBUILDs if missing ---
if [[ ! -d "${PKG_REPO}" ]]; then
    echo "[+] Cloning ArchLinuxARM PKGBUILDs..."
    git clone https://github.com/archlinuxarm/PKGBUILDs.git "${PKG_REPO}"
else
    echo "[=] PKGBUILDs repo already exists."
fi

# --- Ensure linux-rpi directory exists ---
if [[ ! -d "${PKG_PATH}" ]]; then
    echo "ERROR: linux-rpi PKGBUILD directory not found."
    exit 1
fi

cd "${PKG_PATH}"

echo
echo "[+] Checking PKGBUILD version..."
grep -E "pkgver=|pkgrel=" PKGBUILD

# --- Download kernel source ---
echo
echo "[+] Running makepkg -o --clean (download only)..."
makepkg -o --clean

# --- Stage build directory ---
TARGET="${BUILD_ROOT}/${VERSION}"
#SRC_DIR=$(find "${PKG_PATH}/src" -maxdepth 1 -type d -name "linux-${KVER}*" | head -n 1)
SRC_DIR=$(find "${PKG_PATH}/src" -maxdepth 1 -type d -name "linux-*" | head -n 1)

if [[ -z "${SRC_DIR}" ]]; then
    echo "ERROR: Could not locate extracted kernel source directory."
    exit 1
fi

echo
echo "[+] Staging kernel source into: ${TARGET}"
mkdir -p "${TARGET}"
rsync -a --delete "${SRC_DIR}/" "${TARGET}/"

echo "[+] Applying localversion suffix (-lld)..."
echo "-lld" > "${TARGET}/localversion"

# --- Copy Arch config ---
echo "[+] Copying Arch config..."
# cp "${PKG_PATH}/config" "${TARGET}/.config"
cp "${SRC_DIR}/.config" "${TARGET}/.config"

# --- Apply localversion (-lld) ---
echo "[+] Applying localversion suffix..."
echo "-lld" > "${TARGET}/localversion"

echo
echo "[✓] Kernel source staged and tagged:"
echo "    ${TARGET}"
echo
echo "Next steps:"
echo "  1. Run kernel-prep.sh on ${TARGET}"
echo "  2. Run kernel-preflight-build.sh"
echo "  3. At midnight: switch cluster to builder-mode and start pump"
echo
echo "Ready for k3s setup while we wait for midnight."
