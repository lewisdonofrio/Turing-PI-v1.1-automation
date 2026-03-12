#!/usr/bin/env bash
# =====================================================================
#  /home/builder/scripts/kernel-validate-build.sh
#
#  Purpose:
#    Validate a completed OUT-OF-TREE ARMv7 kernel build, and
#    intelligently regenerate any missing required artifacts using
#    incremental `make -j${MAKE_JOBS}` targets, WITHOUT forcing a full
#    rebuild.
#
#  Doctrine:
#    - Source tree: /home/builder/src/kernel
#    - OUT_DIR:     /home/builder/kernel-out (overridable via env)
#    - ARCH=arm, CROSS_COMPILE=arm-linux-gnueabihf-
#    - Must be run from (or will cd into) the kernel source tree.
#    - Intended to be run AFTER kernel-build.sh.
# =====================================================================

set -euo pipefail

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

SRC_DIR=${SRC_DIR:-"/home/builder/src/kernel"}
OUT_DIR=${OUT_DIR:-"/home/builder/kernel-out"}
MAKE_JOBS=${MAKE_JOBS:-14}

ARCH=arm
CROSS_COMPILE=arm-linux-gnueabihf-

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

log() {
  printf '%s\n' "$*"
}

log_section() {
  printf '\n==============================================================\n'
  printf '  %s\n' "$*"
  printf '==============================================================\n\n'
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
}

run_make() {
  local target=$1
  log "Running: make -j${MAKE_JOBS} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} O=${OUT_DIR} ${target}"
  if ! make -j"${MAKE_JOBS}" \
      ARCH="${ARCH}" \
      CROSS_COMPILE="${CROSS_COMPILE}" \
      O="${OUT_DIR}" \
      "${target}"; then
    error "make target failed: ${target}"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------
# Step 0: Sanity checks
# ---------------------------------------------------------------------

log_section "STEP 0: SANITY CHECKS"

if [[ ! -d "${SRC_DIR}" ]]; then
  error "Source directory does not exist: ${SRC_DIR}"
  exit 1
fi

cd "${SRC_DIR}"

if [[ ! -f "Makefile" ]]; then
  error "No Makefile found in ${SRC_DIR}. Is this the kernel source tree?"
  exit 1
fi

if [[ ! -d "${OUT_DIR}" ]]; then
  error "OUT_DIR does not exist: ${OUT_DIR}"
  exit 1
fi

# Enforce source tree cleanliness
if [[ -n "$(git status --porcelain)" ]]; then
  error "Source tree is not clean. Run: git clean -fdx && make mrproper"
  exit 1
fi

# Enforce .config must NOT be in source tree
if [[ -f "${SRC_DIR}/.config" ]]; then
  error ".config found in source tree — this breaks out-of-tree builds."
  error "Remove it: rm ${SRC_DIR}/.config"
  exit 1
fi

log "Kernel source directory: ${SRC_DIR}"
log "Output directory:        ${OUT_DIR}"
log "ARCH:                    ${ARCH}"
log "CROSS_COMPILE:           ${CROSS_COMPILE}"
log "MAKE_JOBS:               ${MAKE_JOBS}"

# ---------------------------------------------------------------------
# Step 1: Detect kernelrelease
# ---------------------------------------------------------------------

log_section "STEP 1: DETECT KERNELRELEASE"

KERNEL_RELEASE=""

if [[ -f "${OUT_DIR}/include/config/kernel.release" ]]; then
  KERNEL_RELEASE=$(<"${OUT_DIR}/include/config/kernel.release")
  log "Detected kernelrelease from include/config/kernel.release: ${KERNEL_RELEASE}"
else
  log "include/config/kernel.release not found, running 'make kernelrelease'..."
  if ! KERNEL_RELEASE=$(make -s \
        ARCH="${ARCH}" \
        CROSS_COMPILE="${CROSS_COMPILE}" \
        O="${OUT_DIR}" \
        kernelrelease 2>/dev/null); then
    error "Unable to determine kernelrelease via 'make kernelrelease'."
    exit 1
  fi
  log "Detected kernelrelease from make kernelrelease: ${KERNEL_RELEASE}"
fi

if [[ -z "${KERNEL_RELEASE}" ]]; then
  error "Kernelrelease is empty. Build is incomplete or corrupted."
  exit 1
fi

MODULES_DIR="${OUT_DIR}/lib/modules/${KERNEL_RELEASE}"

log "Using modules directory: ${MODULES_DIR}"

# ---------------------------------------------------------------------
# Step 2: Define required artifacts
# ---------------------------------------------------------------------

log_section "STEP 2: DEFINE REQUIRED ARTIFACTS"

VMLS="${OUT_DIR}/vmlinux"
IMG="${OUT_DIR}/arch/arm/boot/Image"
ZIMG="${OUT_DIR}/arch/arm/boot/zImage"
SYSMAP="${OUT_DIR}/System.map"
KCONFIG="${OUT_DIR}/.config"
MODSYM="${OUT_DIR}/Module.symvers"
MOD_BUILTIN="${OUT_DIR}/modules.builtin"
MOD_BUILTIN_INFO="${OUT_DIR}/modules.builtin.modinfo"
DTB_DIR="${OUT_DIR}/arch/arm/boot/dts"
OVERLAY_DIR="${DTB_DIR}/overlays"

log "Required artifacts:"
log "  vmlinux:                ${VMLS}"
log "  Image:                  ${IMG}"
log "  zImage:                 ${ZIMG}"
log "  System.map:             ${SYSMAP}"
log "  .config:                ${KCONFIG}"
log "  Module.symvers:         ${MODSYM}"
log "  modules.builtin:        ${MOD_BUILTIN}"
log "  modules.builtin.modinfo:${MOD_BUILTIN_INFO}"
log "  DTB directory:          ${DTB_DIR}"
log "  Overlays directory:     ${OVERLAY_DIR}"
log "  Modules directory:      ${MODULES_DIR}"

missing_critical=0
missing_noncritical=0
declare -a MISSING_CRITICAL_LIST
declare -a MISSING_NONCRITICAL_LIST

mark_missing_critical() {
  missing_critical=1
  MISSING_CRITICAL_LIST+=("$1")
}

mark_missing_noncritical() {
  missing_noncritical=1
  MISSING_NONCRITICAL_LIST+=("$1")
}

# ---------------------------------------------------------------------
# Step 3: Check and regenerate kernel images and metadata
# ---------------------------------------------------------------------

log_section "STEP 3: CHECK AND REGENERATE IMAGES AND METADATA"

# 3.1 .config
if [[ ! -f "${KCONFIG}" ]]; then
  error ".config is missing in OUT_DIR: ${KCONFIG}"
  mark_missing_critical ".config"
else
  log ".config present."
fi

# 3.2 vmlinux
if [[ ! -f "${VMLS}" ]]; then
  error "vmlinux is missing, attempting to regenerate..."
  if run_make "vmlinux"; then
    if [[ -f "${VMLS}" ]]; then
      log "vmlinux regenerated successfully."
    else
      error "vmlinux still missing after make vmlinux."
      mark_missing_critical "vmlinux"
    fi
  else
    mark_missing_critical "vmlinux (make failed)"
  fi
else
  log "vmlinux present."
fi

# 3.3 Image
if [[ ! -f "${IMG}" ]]; then
  error "Image is missing, attempting to regenerate..."
  if run_make "Image"; then
    if [[ -f "${IMG}" ]]; then
      log "Image regenerated successfully."
    else
      error "Image still missing after make Image."
      mark_missing_noncritical "Image"
    fi
  else
    mark_missing_noncritical "Image (make failed)"
  fi
else
  log "Image present."
fi

# 3.4 zImage
if [[ ! -f "${ZIMG}" ]]; then
  error "zImage is missing, attempting to regenerate..."
  if run_make "zImage"; then
    if [[ -f "${ZIMG}" ]]; then
      log "zImage regenerated successfully."
    else
      error "zImage still missing after make zImage."
      mark_missing_noncritical "zImage"
    fi
  else
    mark_missing_noncritical "zImage (make failed)"
  fi
else
  log "zImage present."
fi

# 3.5 System.map
if [[ ! -f "${SYSMAP}" ]]; then
  error "System.map is missing, attempting to regenerate..."
  if run_make "System.map"; then
    if [[ -f "${SYSMAP}" ]]; then
      log "System.map regenerated successfully."
    else
      error "System.map still missing after make System.map."
      mark_missing_noncritical "System.map"
    fi
  else
    mark_missing_noncritical "System.map (make failed)"
  fi
else
  log "System.map present."
fi

# 3.6 Module.symvers
if [[ ! -f "${MODSYM}" ]]; then
  error "Module.symvers is missing, attempting to regenerate (modules_prepare)..."
  if run_make "modules_prepare"; then
    if [[ -f "${MODSYM}" ]]; then
      log "Module.symvers regenerated successfully."
    else
      error "Module.symvers still missing after make modules_prepare."
      mark_missing_critical "Module.symvers"
    fi
  else
    mark_missing_critical "Module.symvers (make failed)"
  fi
else
  log "Module.symvers present."
fi

# 3.7 modules.builtin
if [[ ! -f "${MOD_BUILTIN}" ]]; then
  error "modules.builtin is missing, attempting to regenerate (modules)..."
  if run_make "modules"; then
    if [[ -f "${MOD_BUILTIN}" ]]; then
      log "modules.builtin regenerated successfully."
    else
      error "modules.builtin still missing after make modules."
      mark_missing_noncritical "modules.builtin"
    fi
  else
    mark_missing_noncritical "modules.builtin (make failed)"
  fi
else
  log "modules.builtin present."
fi

# 3.8 modules.builtin.modinfo
if [[ ! -f "${MOD_BUILTIN_INFO}" ]]; then
  error "modules.builtin.modinfo is missing, attempting to regenerate (modules)..."
  if run_make "modules"; then
    if [[ -f "${MOD_BUILTIN_INFO}" ]]; then
      log "modules.builtin.modinfo regenerated successfully."
    else
      error "modules.builtin.modinfo still missing after make modules."
      mark_missing_noncritical "modules.builtin.modinfo"
    fi
  else
    mark_missing_noncritical "modules.builtin.modinfo (make failed)"
  fi
else
  log "modules.builtin.modinfo present."
fi

# ---------------------------------------------------------------------
# Step 4: Check and regenerate DTBs and overlays
# ---------------------------------------------------------------------

log_section "STEP 4: CHECK AND REGENERATE DTBS AND OVERLAYS"

if [[ ! -d "${DTB_DIR}" ]]; then
  error "DTB directory missing: ${DTB_DIR}, attempting to regenerate (dtbs)..."
  if run_make "dtbs"; then
    if [[ -d "${DTB_DIR}" ]]; then
      log "DTB directory regenerated successfully."
    else
      error "DTB directory still missing after make dtbs."
      mark_missing_noncritical "DTB directory"
    fi
  else
    mark_missing_noncritical "DTB directory (make dtbs failed)"
  fi
else
  log "DTB directory present."
fi

DTB_COUNT=0
if [[ -d "${DTB_DIR}" ]]; then
  DTB_COUNT=$(find "${DTB_DIR}" -maxdepth 1 -type f -name "*.dtb" | wc -l || true)
fi

if [[ "${DTB_COUNT}" -eq 0 ]]; then
  error "No DTB files found in ${DTB_DIR}, attempting to regenerate (dtbs)..."
  if run_make "dtbs"; then
    DTB_COUNT=$(find "${DTB_DIR}" -maxdepth 1 -type f -name "*.dtb" | wc -l || true)
    if [[ "${DTB_COUNT}" -gt 0 ]]; then
      log "DTB files regenerated successfully."
    else
      error "No DTB files found after make dtbs."
      mark_missing_noncritical "DTBs"
    fi
  else
    mark_missing_noncritical "DTBs (make dtbs failed)"
  fi
else
  log "Found ${DTB_COUNT} DTB files."
fi

if [[ ! -d "${OVERLAY_DIR}" ]]; then
  error "Overlays directory missing: ${OVERLAY_DIR}, attempting to regenerate (dtbs)..."
  if run_make "dtbs"; then
    if [[ -d "${OVERLAY_DIR}" ]]; then
      log "Overlays directory regenerated successfully."
    else
      error "Overlays directory still missing after make dtbs."
      mark_missing_noncritical "Overlays directory"
    fi
  else
    mark_missing_noncritical "Overlays directory (make dtbs failed)"
  fi
else
  log "Overlays directory present."
fi

DTBO_COUNT=0
if [[ -d "${OVERLAY_DIR}" ]]; then
  DTBO_COUNT=$(find "${OVERLAY_DIR}" -maxdepth 1 -type f -name "*.dtbo" | wc -l || true)
fi

if [[ "${DTBO_COUNT}" -eq 0 ]]; then
  error "No DTBO files found in ${OVERLAY_DIR}, attempting to regenerate (dtbs)..."
  if run_make "dtbs"; then
    DTBO_COUNT=$(find "${OVERLAY_DIR}" -maxdepth 1 -type f -name "*.dtbo" | wc -l || true)
    if [[ "${DTBO_COUNT}" -gt 0 ]]; then
      log "DTBO overlay files regenerated successfully."
    else
      error "No DTBO files found after make dtbs."
      mark_missing_noncritical "DTBO overlays"
    fi
  else
    mark_missing_noncritical "DTBO overlays (make dtbs failed)"
  fi
else
  log "Found ${DTBO_COUNT} DTBO overlay files."
fi

# ---------------------------------------------------------------------
# Step 5: Check modules tree for this kernelrelease
# ---------------------------------------------------------------------

log_section "STEP 5: CHECK MODULES TREE"

if [[ ! -d "${MODULES_DIR}" ]]; then
  error "Modules directory missing for ${KERNEL_RELEASE}: ${MODULES_DIR}"
  error "Attempting to regenerate modules..."
  if run_make "modules"; then
    if [[ -d "${MODULES_DIR}" ]]; then
      log "Modules directory regenerated successfully: ${MODULES_DIR}"
    else
      error "Modules directory still missing after make modules."
      mark_missing_critical "Modules directory"
    fi
  else
    mark_missing_critical "Modules directory (make modules failed)"
  fi
else
  log "Modules directory present: ${MODULES_DIR}"
fi

MODULE_COUNT=0
if [[ -d "${MODULES_DIR}" ]]; then
  MODULE_COUNT=$(find "${MODULES_DIR}" -type f -name "*.ko" | wc -l || true)
fi

if [[ "${MODULE_COUNT}" -eq 0 ]]; then
  error "No .ko modules found under ${MODULES_DIR}, attempting to regenerate (modules)..."
  if run_make "modules"; then
    MODULE_COUNT=$(find "${MODULES_DIR}" -type f -name "*.ko" | wc -l || true)
    if [[ "${MODULE_COUNT}" -gt 0 ]]; then
      log "Kernel modules regenerated successfully (${MODULE_COUNT} .ko files)."
    else
      error "No .ko modules found after make modules."
      mark_missing_critical "Kernel modules"
    fi
  else
    mark_missing_critical "Kernel modules (make modules failed)"
  fi
else
  log "Found ${MODULE_COUNT} .ko modules."
fi

# ---------------------------------------------------------------------
# Step 6: Summary and exit code
# ---------------------------------------------------------------------

log_section "STEP 6: SUMMARY"

if [[ "${missing_critical}" -eq 0 && "${missing_noncritical}" -eq 0 ]]; then
  log "All required kernel artifacts are present and validated."
  log "kernel-validate-build.sh: PASS"
  exit 0
fi

if [[ "${missing_critical}" -ne 0 ]]; then
  error "Critical artifacts missing or failed to regenerate:"
  for item in "${MISSING_CRITICAL_LIST[@]}"; do
    error "  - ${item}"
  done
  error "kernel-validate-build.sh: FAIL (critical missing)"
  exit 1
fi

error "Non-critical artifacts missing or failed to regenerate:"
for item in "${MISSING_NONCRITICAL_LIST[@]}"; do
  error "  - ${item}"
done

log "kernel-validate-build.sh: WARN (non-critical missing)"
exit 0
