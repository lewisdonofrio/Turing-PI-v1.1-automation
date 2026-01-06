#!/bin/bash
# Reality check: kill any stale or stopped collector processes
# This prevents job-control freezes (T state) from breaking the dashboard.
for pid in $(pgrep -f "collector.sh"); do
    if [ "$pid" != "$$" ]; then
        # Kill only other instances, not this one
        kill -9 "$pid" 2>/dev/null
    fi
done

# Ensure required buffer files exist
touch /tmp/cluster-dashboard-A
touch /tmp/cluster-dashboard-B
touch /tmp/cluster-dashboard-current
# =============================================================================
# File: /opt/cluster-dashboard/collector.sh
# Description: Background collector for lean, pump-safe cluster dashboard.
#              Gathers metrics asynchronously and writes double-buffered files
#              in /tmp for the foreground dashboard to render.
# =============================================================================

set -u

BUILDER_NODE="kubenode1.home.lab"

WORKER_NODES=(
  "kubenode2.home.lab"
  "kubenode3.home.lab"
  "kubenode4.home.lab"
  "kubenode5.home.lab"
  "kubenode6.home.lab"
  "kubenode7.home.lab"
)

ALL_NODES=(
  "${BUILDER_NODE}"
  "${WORKER_NODES[@]}"
)

# FAST SSH — no stalls, no DNS, no hostkey prompts, no password fallback
SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=1
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o PreferredAuthentications=publickey
  -o PasswordAuthentication=no
  -o KbdInteractiveAuthentication=no
  -o ChallengeResponseAuthentication=no
  -o GSSAPIAuthentication=no
  -o VerifyHostKeyDNS=no
)

REFRESH_INTERVAL=10

BUF1="/tmp/cluster-dashboard-A"
BUF2="/tmp/cluster-dashboard-B"
PTR="/tmp/cluster-dashboard-current"
LAST_TARGET="${BUF2}"

mkdir -p /tmp

while true; do
    # Decide which buffer to write this round
    if [[ "${LAST_TARGET}" == "${BUF2}" ]]; then
        TARGET="${BUF1}"
    else
        TARGET="${BUF2}"
    fi
    LAST_TARGET="${TARGET}"
    TMP="${TARGET}.tmp"

    # First pass: collect per-node metrics and detect worker distccd
    declare -A NODE_NAME LOAD1 MEM_FREE MEM_AVAIL TEMP_C
    declare -A DISTCCD_ACTIVE DISTCC_JOB_COUNT INCLUDE_SERVER_STATE
    declare -A K3S_SERVER_STATE K3S_AGENT_STATE DISK_FREE

    WORKER_DISTCCD_ACTIVE="no"

    for node in "${ALL_NODES[@]}"; do
        if [[ "$node" == "$(hostname)" ]] || [[ "$node" == "$(hostname -f)" ]]; then
            # Local node
            NODE_NAME["$node"]="$(hostname)"

            LOAD1["$node"]=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "n/a")

            if [ -r /proc/meminfo ]; then
                MEM_FREE["$node"]=$(awk '/MemFree:/ {printf "%.0f", $2/1024}' /proc/meminfo)
                MEM_AVAIL["$node"]=$(awk '/MemAvailable:/ {printf "%.0f", $2/1024}' /proc/meminfo)
            else
                MEM_FREE["$node"]="n/a"
                MEM_AVAIL["$node"]="n/a"
            fi

            if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
                TEMP_C["$node"]=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
            else
                TEMP_C["$node"]="n/a"
            fi

            if command -v systemctl >/dev/null 2>&1; then
                DISTCCD_ACTIVE["$node"]=$(systemctl is-active distccd 2>/dev/null || echo "inactive")
                K3S_SERVER_STATE["$node"]=$(systemctl is-active k3s 2>/dev/null || echo "inactive")
                K3S_AGENT_STATE["$node"]=$(systemctl is-active k3s-agent 2>/dev/null || echo "inactive")
            else
                DISTCCD_ACTIVE["$node"]="inactive"
                K3S_SERVER_STATE["$node"]="inactive"
                K3S_AGENT_STATE["$node"]="inactive"
            fi

            DISTCC_JOB_COUNT["$node"]=$(pgrep distcc | wc -l 2>/dev/null || echo 0)

            if pgrep include-server >/dev/null 2>&1; then
                INCLUDE_SERVER_STATE["$node"]="running"
            else
                INCLUDE_SERVER_STATE["$node"]="none"
            fi

            DISK_FREE["$node"]=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}')
            [[ -z "${DISK_FREE["$node"]}" ]] && DISK_FREE["$node"]="n/a"
        else
            # Remote node via SSH
            RAW=$(ssh "${SSH_OPTS[@]}" "${node}" '
                NODE_NAME=$(hostname)
                LOAD1=$(awk "{print \$1}" /proc/loadavg 2>/dev/null || echo "n/a")

                if [ -r /proc/meminfo ]; then
                    MEM_FREE=$(awk "/MemFree:/ {printf \"%.0f\", \$2/1024}" /proc/meminfo)
                    MEM_AVAIL=$(awk "/MemAvailable:/ {printf \"%.0f\", \$2/1024}" /proc/meminfo)
                else
                    MEM_FREE="n/a"
                    MEM_AVAIL="n/a"
                fi

                if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
                    TEMP_C=$(awk "{printf \"%.1f\", \$1/1000}" /sys/class/thermal/thermal_zone0/temp)
                else
                    TEMP_C="n/a"
                fi

                if command -v systemctl >/dev/null 2>&1; then
                    DISTCCD_ACTIVE=$(systemctl is-active distccd 2>/dev/null || echo "inactive")
                    K3S_SERVER_STATE=$(systemctl is-active k3s 2>/dev/null || echo "inactive")
                    K3S_AGENT_STATE=$(systemctl is-active k3s-agent 2>/dev/null || echo "inactive")
                else
                    DISTCCD_ACTIVE="inactive"
                    K3S_SERVER_STATE="inactive"
                    K3S_AGENT_STATE="inactive"
                fi

                DISTCC_JOB_COUNT=$(pgrep distcc | wc -l 2>/dev/null || echo 0)

                if pgrep include-server >/dev/null 2>&1; then
                    INCLUDE_SERVER_STATE="running"
                else
                    INCLUDE_SERVER_STATE="none"
                fi

                DISK_FREE=$(df -h / 2>/dev/null | awk "NR==2 {print \$4}")
                [ -z "${DISK_FREE}" ] && DISK_FREE="n/a"

                echo "NODE=${NODE_NAME}"
                echo "LOAD1=${LOAD1}"
                echo "MEM_FREE_MB=${MEM_FREE}"
                echo "MEM_AVAIL_MB=${MEM_AVAIL}"
                echo "TEMP_C=${TEMP_C}"
                echo "DISTCCD_ACTIVE=${DISTCCD_ACTIVE}"
                echo "DISTCC_JOB_COUNT=${DISTCC_JOB_COUNT}"
                echo "INCLUDE_SERVER_STATE=${INCLUDE_SERVER_STATE}"
                echo "K3S_SERVER_STATE=${K3S_SERVER_STATE}"
                echo "K3S_AGENT_STATE=${K3S_AGENT_STATE}"
                echo "DISK_FREE=${DISK_FREE}"
            ' 2>/dev/null) || RAW=""

            if [[ -z "${RAW}" ]]; then
                NODE_NAME["$node"]="${node}"
                LOAD1["$node"]="n/a"
                MEM_FREE["$node"]="n/a"
                MEM_AVAIL["$node"]="n/a"
                TEMP_C["$node"]="n/a"
                DISTCCD_ACTIVE["$node"]="inactive"
                DISTCC_JOB_COUNT["$node"]="0"
                INCLUDE_SERVER_STATE["$node"]="none"
                K3S_SERVER_STATE["$node"]="inactive"
                K3S_AGENT_STATE["$node"]="inactive"
                DISK_FREE["$node"]="n/a"
            else
                eval "$(printf '%s\n' "${RAW}" | sed -n 's/^\([A-Z0-9_]*\)=\(.*\)$/\1="\2"/p')"

                NODE_NAME["$node"]="${NODE}"
                LOAD1["$node"]="${LOAD1}"
                MEM_FREE["$node"]="${MEM_FREE_MB}"
                MEM_AVAIL["$node"]="${MEM_AVAIL_MB}"
                TEMP_C["$node"]="${TEMP_C}"
                DISTCCD_ACTIVE["$node"]="${DISTCCD_ACTIVE}"
                DISTCC_JOB_COUNT["$node"]="${DISTCC_JOB_COUNT}"
                INCLUDE_SERVER_STATE["$node"]="${INCLUDE_SERVER_STATE}"
                K3S_SERVER_STATE["$node"]="${K3S_SERVER_STATE}"
                K3S_AGENT_STATE["$node"]="${K3S_AGENT_STATE}"
                DISK_FREE["$node"]="${DISK_FREE}"
            fi
        fi

        # Track if any worker has distccd active
        if [[ "$node" != "${BUILDER_NODE}" && "${DISTCCD_ACTIVE["$node"]}" == "active" ]]; then
            WORKER_DISTCCD_ACTIVE="yes"
        fi
    done

    # Second pass: write formatted table to TMP, then atomically swap
    {
        printf "%-12s %-8s %-6s %-8s %-8s %-6s %-8s %-6s %-6s %-8s %-10s %-8s\n" \
            "Node" "Mode" "L1" "Free" "Avail" "Temp" "distccd" "Jobs" "Inc" "k3s" "k3s-agent" "DiskFree"
        echo "------------------------------------------------------------------------------------------------------------------------"

        for node in "${ALL_NODES[@]}"; do
            name="${NODE_NAME["$node"]}"

            mode="unknown"
            if [[ "$node" == "${BUILDER_NODE}" ]]; then
                if [[ "${K3S_SERVER_STATE["$node"]}" == "active" ]]; then
                    mode="cluster"
                elif [[ "${WORKER_DISTCCD_ACTIVE}" == "yes" ]]; then
                    mode="build"
                fi
            else
                if [[ "${K3S_AGENT_STATE["$node"]}" == "active" ]]; then
                    mode="cluster"
                elif [[ "${DISTCCD_ACTIVE["$node"]}" == "active" ]]; then
                    mode="build"
                fi
            fi

            printf "%-12s %-8s %-6s %-8s %-8s %-6s %-8s %-6s %-6s %-8s %-10s %-8s\n" \
                "${name}" \
                "${mode}" \
                "${LOAD1["$node"]}" \
                "${MEM_FREE["$node"]}" \
                "${MEM_AVAIL["$node"]}" \
                "${TEMP_C["$node"]}" \
                "${DISTCCD_ACTIVE["$node"]}" \
                "${DISTCC_JOB_COUNT["$node"]}" \
                "${INCLUDE_SERVER_STATE["$node"]}" \
                "${K3S_SERVER_STATE["$node"]}" \
                "${K3S_AGENT_STATE["$node"]}" \
                "${DISK_FREE["$node"]}"
        done

        echo
        echo "Collected at: $(date)  (interval: ${REFRESH_INTERVAL}s)"
    } > "${TMP}"

    mv -f "${TMP}" "${TARGET}"
    echo "${TARGET}" > "${PTR}.tmp"
    mv -f "${PTR}.tmp" "${PTR}"

    sleep "${REFRESH_INTERVAL}"
done
