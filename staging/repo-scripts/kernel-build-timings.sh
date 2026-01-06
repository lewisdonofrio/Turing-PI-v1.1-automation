#!/bin/sh
set -euo pipefail

# ---------------------------------------------------------------------
#  /home/builder/scripts/kernel-build-timings.sh
#
#  Purpose:
#    Extract build timing information from kernel build logs.
#
#    Supports two modes:
#      1. No argument:
#           Automatically selects the newest real build log matching:
#             /home/builder/build-logs/build-YYYYMMDD-HHMMSS.log
#
#      2. One argument:
#           Uses the explicitly provided log file path.
#
#    Timing is computed using:
#      - Start time encoded in the log filename
#      - End time from the log file's modification timestamp
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Ignores latest.log symlink unless explicitly passed.
#    - Works on any timestamped build log.
# ---------------------------------------------------------------------

LOGDIR="/home/builder/build-logs"

# ---------------------------------------------------------------------
#  Select log file
# ---------------------------------------------------------------------

if [ $# -eq 1 ]; then
    LOGFILE="$1"
else
    LOGFILE=$(ls -1t "${LOGDIR}"/build-*.log 2>/dev/null | head -n 1 || true)
fi

if [ -z "${LOGFILE}" ]; then
    echo "ERROR: No build logs found in ${LOGDIR}"
    exit 1
fi

if [ ! -f "${LOGFILE}" ]; then
    echo "ERROR: Log file not found: ${LOGFILE}"
    exit 1
fi

# ---------------------------------------------------------------------
#  Extract start timestamp from filename
# ---------------------------------------------------------------------

BASENAME=$(basename "${LOGFILE}")

# Expecting: build-YYYYMMDD-HHMMSS.log
START_RAW=$(echo "${BASENAME}" | sed -n 's/^build-\([0-9]\{8\}\)-\([0-9]\{6\}\)\.log$/\1 \2/p')

if [ -z "${START_RAW}" ]; then
    echo "ERROR: Could not parse start timestamp from filename: ${BASENAME}"
    exit 1
fi

DATE_PART=$(echo "${START_RAW}" | awk '{print $1}')
TIME_PART=$(echo "${START_RAW}" | awk '{print $2}')

# Normalize formats:
#   YYYYMMDD → YYYY-MM-DD
#   HHMMSS   → HH:MM:SS

DATE_FMT="${DATE_PART:0:4}-${DATE_PART:4:2}-${DATE_PART:6:2}"
TIME_FMT="${TIME_PART:0:2}:${TIME_PART:2:2}:${TIME_PART:4:2}"

START_TS="${DATE_FMT} ${TIME_FMT}"

# Convert to epoch
START_EPOCH=$(date -d "${START_TS}" +%s)

# ---------------------------------------------------------------------
#  Extract end timestamp
# ---------------------------------------------------------------------
# We use the file modification time because kernel-build.sh writes the
# log continuously and finishes with "Build completed".

END_EPOCH=$(stat -c %Y "${LOGFILE}")

# ---------------------------------------------------------------------
#  Compute elapsed time
# ---------------------------------------------------------------------

ELAPSED=$((END_EPOCH - START_EPOCH))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

# ---------------------------------------------------------------------
#  Output summary
# ---------------------------------------------------------------------

echo "Log file: ${LOGFILE}"
echo "Start time: ${START_TS}"
echo "End time:   $(date -d "@${END_EPOCH}" +"%Y-%m-%d %H:%M:%S")"
echo "Elapsed:    ${ELAPSED} seconds (${MINUTES}m ${SECONDS}s)"
exit 0
