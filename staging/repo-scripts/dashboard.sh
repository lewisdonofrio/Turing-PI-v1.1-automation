#!/bin/bash

# Reality check: ensure pointer file exists
PTR="/tmp/cluster-dashboard-current"

if [ ! -f "$PTR" ]; then
    echo "Pointer file missing. Creating placeholder..."
    echo "/tmp/cluster-dashboard-A" > "$PTR"
    touch /tmp/cluster-dashboard-A
fi

# =============================================================================
# File: /opt/cluster-dashboard/dashboard.sh
# Description: Foreground renderer for lean, pump-safe cluster dashboard.
#              Reads precomputed buffer from /tmp and prints instantly.
# =============================================================================

set -u

# OPTIONAL RECOMMENDATION: ensure collector is running
if ! pgrep -f "collector.sh" >/dev/null; then
    echo "Collector is not running. Start it with:"
    echo "  nohup ./collector.sh >/tmp/collector.log 2>&1 &"
    exit 1
fi

PTR="/tmp/cluster-dashboard-current"

while true; do
    printf "\033[H\033[2J"
    echo "============================================================================="
    echo " CLUSTER DASHBOARD - $(date)"
    echo "============================================================================="
    echo

    if [[ -f "${PTR}" ]]; then
        BUF=$(cat "${PTR}" 2>/dev/null || echo "")
        if [[ -n "${BUF}" && -f "${BUF}" ]]; then
            cat "${BUF}"
        else
            echo "No data buffer available yet. Waiting for collector..."
        fi
    else
        echo "Collector not running or no buffer pointer yet."
    fi

    echo
    echo "Press Ctrl-C to exit. Renderer refresh: 1s (collector interval is separate)."
    sleep 1
done
