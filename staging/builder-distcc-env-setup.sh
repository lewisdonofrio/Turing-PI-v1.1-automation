#!/bin/sh

# =====================================================================
#  /home/builder/builder-distcc-env-setup.sh
#
#  Purpose:
#    Deterministic distcc environment setup for builder user.
#    Provides shared distcc settings for kernel builds and other
#    distributed compile workflows.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Safe to source multiple times.
#    - Does NOT start or stop pump.
#    - Does NOT set DISTCC_HOSTS (hosts file is authoritative).
# =====================================================================

# Ensure our scripts shadow system pump/distcc wrappers
export PATH="/home/builder/scripts:${PATH}"

# ---------------------------------------------------------------------
#  Validation
# ---------------------------------------------------------------------

if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: builder-distcc-env-setup.sh must be sourced as builder user" >&2
    return 1 2>/dev/null || exit 1
fi

# ---------------------------------------------------------------------
#  Distcc base configuration
# ---------------------------------------------------------------------

# Distcc log file
export DISTCC_LOG="/home/builder/build-logs/distcc.log"

# Distcc state directory
export DISTCC_DIR="/home/builder/.distcc"

# Do not silently fall back to local-only
export DISTCC_FALLBACK="0"

# Local jobs limit on the builder
export DISTCC_JOBS="8"

# Verbose logging
export DISTCC_VERBOSE="1"

# ---------------------------------------------------------------------
#  Sanity notes (for future maintainers)
# ---------------------------------------------------------------------
# - DISTCC_HOSTS must remain unset; ~/.distcc/hosts is the single
#   source of truth and must NOT contain ',cpp' or ',lzo' entries.
# - PATH, CC, and HOSTCC are enforced by:
#     /home/builder/scripts/kernel-build-preflight.sh
# - Pump include-server startup and verification are enforced
#   in the preflight script, not here.
# ---------------------------------------------------------------------

# Successful setup
return 0 2>/dev/null || exit 0
