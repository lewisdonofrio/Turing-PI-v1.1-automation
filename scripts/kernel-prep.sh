#!/bin/bash
# /opt/ansible-k3s-cluster/scripts/kernel-prep.sh
# Prepare a clean, out-of-tree kernel build environment.
# Doctrine:
#   - SRC must remain pristine
#   - BUILD contains all generated state
#   - .config lives ONLY in BUILD
#   - olddefconfig runs out-of-tree
#   - mrproper runs ONLY when SRC is dirty

set -euo pipefail

LOG="/home/builder/kernel-prep.log"
SRC="/home/builder/src/kernel"
BUILD="/home/builder/kernel-build"
CONFIG="/opt/ansible-k3s-cluster/kernel-configs/cm3plus.config"

echo "=== kernel-prep.sh ===" | tee "$LOG"
echo "Start: $(date -u)" | tee -a "$LOG"

# ------------------------------------------------------------
# Verify kernel source
# ------------------------------------------------------------
if [[ ! -d "$SRC" ]]; then
    echo "ERROR: Kernel source tree missing at $SRC" | tee -a "$LOG"
    exit 1
fi
echo "Kernel source tree verified at $SRC" | tee -a "$LOG"

# ------------------------------------------------------------
# Ensure build directory exists
# ------------------------------------------------------------
mkdir -p "$BUILD"
echo "Build directory: $BUILD" | tee -a "$LOG"

# ------------------------------------------------------------
# Verify canonical config
# ------------------------------------------------------------
if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Canonical config missing at $CONFIG" | tee -a "$LOG"
    exit 1
fi
echo "Canonical config found at $CONFIG" | tee -a "$LOG"

# ------------------------------------------------------------
# Detect dirty source tree
# ------------------------------------------------------------
DIRTY=0

if find "$SRC" -maxdepth 1 -name ".config" | grep -q .; then
    echo "Detected .config in SRC (forbidden in out-of-tree builds)." | tee -a "$LOG"
    DIRTY=1
fi

if find "$SRC/include" -maxdepth 2 -name "auto.conf*" 2>/dev/null | grep -q .; then
    echo "Detected auto.conf in SRC/include (forbidden)." | tee -a "$LOG"
    DIRTY=1
fi

if find "$SRC/include/generated" -type f 2>/dev/null | grep -q .; then
    echo "Detected include/generated files in SRC (forbidden)." | tee -a "$LOG"
    DIRTY=1
fi

# ------------------------------------------------------------
# Clean if dirty
# ------------------------------------------------------------
if [[ "$DIRTY" -eq 1 ]]; then
    echo "Source tree is dirty. Running 'make mrproper' in $SRC..." | tee -a "$LOG"
    make -C "$SRC" mrproper 2>&1 | tee -a "$LOG"
else
    echo "Source tree appears clean. Skipping mrproper." | tee -a "$LOG"
fi

# ------------------------------------------------------------
# Double-check cleanliness
# ------------------------------------------------------------
if find "$SRC/include/generated" -type f 2>/dev/null | grep -q .; then
    echo "ERROR: include/generated files still present in SRC after mrproper." | tee -a "$LOG"
    exit 1
fi

if find "$SRC" -maxdepth 1 -name ".config" | grep -q .; then
    echo "ERROR: .config still present in SRC after mrproper." | tee -a "$LOG"
    exit 1
fi

echo "Source tree is clean and ready for out-of-tree build." | tee -a "$LOG"

# ------------------------------------------------------------
# Restore config into BUILD (never SRC)
# ------------------------------------------------------------
echo "Synchronizing .config into BUILD..." | tee -a "$LOG"
cp "$CONFIG" "$BUILD/.config"

# ------------------------------------------------------------
# Run olddefconfig out-of-tree
# ------------------------------------------------------------
echo "Running olddefconfig in out-of-tree mode..." | tee -a "$LOG"
make -C "$SRC" O="$BUILD" olddefconfig 2>&1 | tee -a "$LOG"

# ------------------------------------------------------------
# Sanity: ensure SRC not polluted
# ------------------------------------------------------------
if find "$SRC/include/generated" -type f 2>/dev/null | grep -q .; then
    echo "ERROR: Generated files appeared in SRC after olddefconfig." | tee -a "$LOG"
    exit 1
fi

echo "olddefconfig complete. Config and generated headers are in BUILD." | tee -a "$LOG"

# ------------------------------------------------------------
# Optional: warm include cache (helps pump mode)
# ------------------------------------------------------------
echo "Warming include cache (optional step)..." | tee -a "$LOG"
find "$SRC" -type f -name '*.h' | head -n 500 | xargs -r cat > /dev/null
echo "Include cache warmed." | tee -a "$LOG"

echo "Prep complete." | tee -a "$LOG"
echo "End: $(date -u)" | tee -a "$LOG"
