#!/bin/bash
# /opt/ansible-k3s-cluster/scripts/kernel-build.sh
# Distributed, pump-mode, out-of-tree kernel build + packaging.
# Doctrine:
#   - SRC must remain pristine
#   - BUILD contains all generated state
#   - .config lives ONLY in BUILD
#   - pump used ONLY for compile phase
#   - packaging uses staged artifacts only

set -euo pipefail

LOG="/home/builder/kernel-build.log"
SRC="/home/builder/src/kernel"
BUILD="/home/builder/kernel-build"
CONFIG="/opt/ansible-k3s-cluster/kernel-configs/cm3plus.config"

PKGNAME="linux-rpi-6.18-k3s"
STAGE_ROOT="/home/builder/pkgstage"
STAGE="${STAGE_ROOT}/${PKGNAME}"
PKGOUT="/home/builder/pkgout"

MAX_JOBS=14
DEFAULT_JOBS=14

echo "=== kernel-build.sh ===" | tee "$LOG"
echo "Start: $(date -u)" | tee -a "$LOG"

# ------------------------------------------------------------
# Parse job count
# ------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    JOBS="$DEFAULT_JOBS"
    echo "No -jN provided. Defaulting to -j$JOBS" | tee -a "$LOG"
else
    JOBS_RAW="$1"
    if [[ "$JOBS_RAW" =~ ^-j([0-9]+)$ ]]; then
        JOBS="${BASH_REMATCH[1]}"
    else
        echo "ERROR: Expected -jN argument (for example: -j8)." | tee -a "$LOG"
        exit 1
    fi
fi

if [[ "$JOBS" -gt "$MAX_JOBS" ]]; then
    echo "ERROR: Concurrency j$JOBS exceeds safe limit j$MAX_JOBS." | tee -a "$LOG"
    exit 1
fi

echo "Concurrency accepted: -j$JOBS" | tee -a "$LOG"

# ------------------------------------------------------------
# Verify SRC and BUILD
# ------------------------------------------------------------
if [[ ! -d "$SRC" ]]; then
    echo "ERROR: Kernel source tree missing at $SRC" | tee -a "$LOG"
    exit 1
fi

if [[ ! -d "$BUILD" ]]; then
    echo "ERROR: Build directory missing at $BUILD. Run kernel-prep.sh first." | tee -a "$LOG"
    exit 1
fi

if [[ ! -f "$BUILD/.config" ]]; then
    echo "ERROR: $BUILD/.config missing. Run kernel-prep.sh first." | tee -a "$LOG"
    exit 1
fi

# Doctrine enforcement: SRC must not be polluted
if find "$SRC" -maxdepth 1 -name ".config" | grep -q .; then
    echo "ERROR: .config present in SRC. This violates out-of-tree doctrine." | tee -a "$LOG"
    exit 1
fi

if find "$SRC/include/generated" -type f 2>/dev/null | grep -q .; then
    echo "ERROR: include/generated files present in SRC. This violates out-of-tree doctrine." | tee -a "$LOG"
    exit 1
fi

echo "Source and build trees verified for out-of-tree build." | tee -a "$LOG"

# ------------------------------------------------------------
# Distcc / pump environment
# ------------------------------------------------------------
export DISTCC_HOSTS="kubenode2/7 kubenode3/7 kubenode4/7 kubenode5/7 kubenode6/7 kubenode7/7 localhost/2"

echo "DISTCC_HOSTS:" | tee -a "$LOG"
echo "$DISTCC_HOSTS" | tee -a "$LOG"

if ! command -v pump >/dev/null 2>&1; then
    echo "ERROR: pump not found in PATH. Ensure distcc-pump is installed." | tee -a "$LOG"
    exit 1
fi

# ------------------------------------------------------------
# Build kernel with pump
# ------------------------------------------------------------
echo "Starting distributed kernel build (pump mode)..." | tee -a "$LOG"
pump make -C "$SRC" O="$BUILD" -j"$JOBS" 2>&1 | tee -a "$LOG"
echo "Kernel build complete." | tee -a "$LOG"

# ------------------------------------------------------------
# Determine kernel release
# ------------------------------------------------------------
echo "Determining kernel release..." | tee -a "$LOG"
KREL="$(make -s -C "$SRC" O="$BUILD" kernelrelease)"
echo "Kernel release: $KREL" | tee -a "$LOG"

# ------------------------------------------------------------
# Install modules locally (needed for packaging)
# ------------------------------------------------------------
echo "Installing modules for $KREL..." | tee -a "$LOG"
sudo make -C "$SRC" O="$BUILD" modules_install 2>&1 | tee -a "$LOG"
echo "Modules installed to /lib/modules/$KREL" | tee -a "$LOG"

# ------------------------------------------------------------
# Stage artifacts for packaging
# ------------------------------------------------------------
echo "Staging kernel artifacts for packaging..." | tee -a "$LOG"

rm -rf "$STAGE"
mkdir -p "$STAGE"/{dtbs,overlays,modules/lib/modules}

# Kernel image -> kernel7.img
ZIMAGE_SRC="$BUILD/arch/arm/boot/zImage"
if [[ ! -f "$ZIMAGE_SRC" ]]; then
    echo "ERROR: zImage not found at $ZIMAGE_SRC" | tee -a "$LOG"
    exit 1
fi
cp "$ZIMAGE_SRC" "$STAGE/kernel7.img"

# DTBs (bcm*.dtb)
DTB_SRC_DIR="$BUILD/arch/arm/boot/dts"
if [[ -d "$DTB_SRC_DIR" ]]; then
    cp "$DTB_SRC_DIR"/bcm*.dtb "$STAGE/dtbs/" 2>/dev/null || true
else
    echo "WARNING: DTB source directory $DTB_SRC_DIR not found." | tee -a "$LOG"
fi

# Overlays
OVERLAY_SRC_DIR="$BUILD/arch/arm/boot/dts/overlays"
if [[ -d "$OVERLAY_SRC_DIR" ]]; then
    cp "$OVERLAY_SRC_DIR"/*.dtbo "$STAGE/overlays/" 2>/dev/null || true
else
    echo "WARNING: overlay source directory $OVERLAY_SRC_DIR not found." | tee -a "$LOG"
fi

# Modules -> modules/lib/modules/$KREL
if [[ -d "/lib/modules/$KREL" ]]; then
    cp -a "/lib/modules/$KREL" "$STAGE/modules/lib/modules/"
else
    echo "ERROR: /lib/modules/$KREL not found after modules_install." | tee -a "$LOG"
    exit 1
fi

echo "Artifacts staged under $STAGE" | tee -a "$LOG"

# ------------------------------------------------------------
# Build package via PKGBUILD
# ------------------------------------------------------------
echo "Building package $PKGNAME..." | tee -a "$LOG"
cd /opt/ansible-k3s-cluster/pkgbuilds/linux-rpi-6.18-k3s

rm -f "${PKGNAME}"-*.pkg.tar.zst

makepkg -f --clean --cleanbuild --nodeps --nocheck --noconfirm 2>&1 | tee -a "$LOG"

mkdir -p "$PKGOUT"
mv "${PKGNAME}"-*.pkg.tar.zst "$PKGOUT/"

echo "Package(s) created in $PKGOUT:" | tee -a "$LOG"
ls -1 "$PKGOUT"/"${PKGNAME}"-*.pkg.tar.zst | tee -a "$LOG"

echo "End: $(date -u)" | tee -a "$LOG"
