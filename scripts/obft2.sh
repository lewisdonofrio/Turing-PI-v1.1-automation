#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  OBFT 2.0 - Offline Boot Forensics & Pre-Boot Validator
#  Mode: PREBOOT (primary), POSTMORTEM (future extension)
# ==============================================================

VERSION="2.0.0"

BOOT="/boot"
MODDIR="/usr/lib/modules"
FSTAB="/etc/fstab"
CMDLINE="$BOOT/cmdline.txt"
CONFIGTXT="$BOOT/config.txt"

KERNEL_IMG="kernel7.img"
INITRAMFS="initramfs-linux.img"
CM3_DTB="bcm2710-rpi-cm3.dtb"

REQUIRED_KCONFIG=(
  "CONFIG_NF_NAT"
  "CONFIG_IP_NF_TARGET_MASQUERADE"
  "CONFIG_NETFILTER_XT_MATCH_COMMENT"
  "CONFIG_BRIDGE_NETFILTER"
)

# --------------------------------------------------------------
# Helpers
# --------------------------------------------------------------
log()  { printf '%s\n' "$*" >&2; }
die()  { log "FATAL: $*"; exit 1; }
warn() { log "WARN:  $*"; }

require_file() {
    [[ -f "$1" ]] || die "Missing required file: $1"
}

require_dir() {
    [[ -d "$1" ]] || die "Missing required directory: $1"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# --------------------------------------------------------------
# 1) Detect kernel release from modules or image
# --------------------------------------------------------------
detect_krel_from_modules() {
    # Prefer: single modules dir under /usr/lib/modules
    local dirs
    mapfile -t dirs < <(find "$MODDIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null || true)
    if (( ${#dirs[@]} == 1 )); then
        echo "${dirs[0]}"
        return 0
    fi
    # Fallback: uname -r
    uname -r
}

detect_krel_from_image() {
    local img="$1"
    if ! have_cmd strings; then
        warn "strings not available; falling back to uname -r for KREL"
        uname -r
        return
    fi
    # Heuristic: look for something that looks like a release
    strings "$img" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || uname -r
}

# --------------------------------------------------------------
# 2) Kernel / modules / initramfs / DTB cross-checks
# --------------------------------------------------------------
check_kernel_image() {
    log "--- Checking kernel image ---"
    local img="$BOOT/$KERNEL_IMG"
    require_file "$img"
    log "Kernel image: $img"

    local krel_img
    krel_img=$(detect_krel_from_image "$img" || true)
    log "Kernelrelease (from image heuristic): $krel_img"
}

check_modules_tree() {
    log "--- Checking modules tree ---"
    require_dir "$MODDIR"

    local krel_mod
    krel_mod=$(detect_krel_from_modules)
    log "Detected modules KREL: $krel_mod"

    local mdir="$MODDIR/$krel_mod"
    require_dir "$mdir"

    if ! find "$mdir" -name '*.ko' | grep -q .; then
        die "No .ko modules found under $mdir"
    fi

    if [[ ! -f "$mdir/modules.dep" ]]; then
        warn "modules.dep missing under $mdir (depmod may be needed)"
    fi

    echo "$krel_mod"
}

check_initramfs() {
    log "--- Checking initramfs ---"
    local img="$BOOT/$INITRAMFS"
    require_file "$img"

    if [[ ! -s "$img" ]]; then
        die "Initramfs $img exists but is empty"
    fi

    log "Initramfs present and non-empty: $img"
}

check_dtb() {
    log "--- Checking DTB ---"
    local dtb="$BOOT/$CM3_DTB"
    require_file "$dtb"
    log "DTB present: $dtb"
}

# --------------------------------------------------------------
# 3) config.txt / cmdline.txt / fstab sanity
# --------------------------------------------------------------
check_config_txt() {
    log "--- Checking config.txt ---"
    require_file "$CONFIGTXT"

    grep -q "^kernel=$KERNEL_IMG" "$CONFIGTXT" \
        || warn "config.txt: kernel= line missing or not $KERNEL_IMG"

    grep -q "^device_tree=$CM3_DTB" "$CONFIGTXT" \
        || warn "config.txt: device_tree= line missing or not $CM3_DTB"

    grep -q "^initramfs $INITRAMFS followkernel" "$CONFIGTXT" \
        || warn "config.txt: initramfs line missing or not 'initramfs $INITRAMFS followkernel'"

    log "config.txt (relevant lines):"
    grep -E '^kernel=|^device_tree=|^initramfs ' "$CONFIGTXT" || true
}

check_cmdline_and_fstab() {
    log "--- Checking cmdline.txt & fstab ---"
    require_file "$CMDLINE"

    local root_uuid
    root_uuid=$(blkid -s UUID -o value /dev/mmcblk0p2 2>/dev/null || true)
    if [[ -z "$root_uuid" ]]; then
        warn "Could not detect root UUID from /dev/mmcblk0p2"
    else
        log "Detected root UUID: $root_uuid"
        if ! grep -q "root=UUID=$root_uuid" "$CMDLINE"; then
            warn "cmdline.txt does not reference root=UUID=$root_uuid"
        fi
    fi

    log "cmdline.txt:"
    cat "$CMDLINE"

    if [[ -f "$FSTAB" ]]; then
        log "/etc/fstab (/ line):"
        grep ' / ' "$FSTAB" || true
    else
        warn "/etc/fstab missing"
    fi
}

# --------------------------------------------------------------
# 4) Kernel config option checks (from /proc/config.gz or /boot/config-*)
# --------------------------------------------------------------
find_kernel_config() {
    if [[ -f /proc/config.gz ]]; then
        echo "/proc/config.gz"
        return 0
    fi

    local krel
    krel=$(uname -r)
    if [[ -f "$BOOT/config-$krel" ]]; then
        echo "$BOOT/config-$krel"
        return 0
    fi

    # Fallback: first config-* in /boot
    local cfg
    cfg=$(ls "$BOOT"/config-* 2>/dev/null | head -n1 || true)
    [[ -n "$cfg" ]] && echo "$cfg" && return 0

    return 1
}

check_kernel_options() {
    log "--- Checking required kernel options ---"

    local cfg
    cfg=$(find_kernel_config || true)
    if [[ -z "$cfg" ]]; then
        warn "No kernel config found (/proc/config.gz or /boot/config-*); skipping option checks"
        return
    fi

    log "Using kernel config: $cfg"

    local reader="cat"
    [[ "$cfg" == "/proc/config.gz" ]] && reader="zcat"

    for opt in "${REQUIRED_KCONFIG[@]}"; do
        if $reader "$cfg" | grep -q "^$opt="; then
            log "OK:   $opt"
        else
            warn "MISS: $opt"
        fi
    done
}

# --------------------------------------------------------------
# 5) PREBOOT mode: "Will this node boot?"
# --------------------------------------------------------------
run_preboot() {
    log "OBFT 2.0 PREBOOT - version $VERSION"
    log

    require_dir "$BOOT"
    require_dir "$MODDIR"

    check_kernel_image
    krel_mod=$(check_modules_tree)
    check_initramfs
    check_dtb
    check_config_txt
    check_cmdline_and_fstab
    check_kernel_options

    log
    log "SUMMARY:"
    log "  Kernel image:   $BOOT/$KERNEL_IMG"
    log "  Modules KREL:   $krel_mod"
    log "  Initramfs:      $BOOT/$INITRAMFS"
    log "  DTB:            $BOOT/$CM3_DTB"
    log
    log "If no FATAL messages appeared above, this node is structurally ready to attempt a boot."
}

# --------------------------------------------------------------
# 6) POSTMORTEM mode (stub for future extension)
# --------------------------------------------------------------
run_postmortem() {
    log "OBFT 2.0 POSTMORTEM - version $VERSION"
    die "POSTMORTEM mode not implemented yet in this skeleton."
}

# --------------------------------------------------------------
# 7) CLI
# --------------------------------------------------------------
usage() {
    cat <<EOF
OBFT 2.0 - Offline Boot Forensics & Pre-Boot Validator (v$VERSION)

Usage:
  $0 preboot      # Validate kernel/modules/initramfs/DTB/config before reboot
  $0 postmortem   # Future: analyze dead rootfs / journals
EOF
}

main() {
    local mode="${1:-}"

    case "$mode" in
        preboot)
            run_preboot
            ;;
        postmortem)
            run_postmortem
            ;;
        ""|-h|--help)
            usage
            ;;
        *)
            die "Unknown mode: $mode"
            ;;
    esac
}

main "$@"
