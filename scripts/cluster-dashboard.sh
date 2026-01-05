#!/bin/bash
# =============================================================================
# File: /opt/cluster-dashboard/cluster-dashboard.sh
# Description: Lean, fast, stability-focused cluster dashboard for k3s + distcc.
#              Local-node aware, builder-aware, pump-mode safe.
#              Includes CPU% and DiskFree, with fast SSH.
# =============================================================================

set -u

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

if [[ "${TERM:-}" != "dumb" ]]; then
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_RESET=""
fi

status_color() {
    case "$1" in
        active|running) printf "%s%s%s" "$C_GREEN" "$1" "$C_RESET" ;;
        inactive|none)  printf "%s%s%s" "$C_YELLOW" "$1" "$C_RESET" ;;
        failed|error)   printf "%s%s%s" "$C_RED" "$1" "$C_RESET" ;;
        *)              printf "%s" "$1" ;;
    esac
}

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------

print_header() {
    printf "\033[H\033[2J"
    echo "============================================================================="
    echo " CLUSTER DASHBOARD - $(date)"
    echo "============================================================================="
    echo
}

# -----------------------------------------------------------------------------
# CPU% helpers (per node, /proc/stat deltas)
# -----------------------------------------------------------------------------

declare -A PREV_CPU_TOTAL
declare -A PREV_CPU_IDLE

compute_cpu_usage() {
    # args: node_name stat_line
    local node="$1"
    local stat_line="$2"

    # /proc/stat line: cpu  user nice system idle iowait irq softirq steal guest guest_nice
    # we only need: total = sum(all), idle = idle + iowait
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice <<< "${stat_line}"

    local idle_all=$(( idle + iowait ))
    local non_idle=$(( user + nice + system + irq + softirq + steal ))
    local total=$(( idle_all + non_idle ))

    local prev_total=${PREV_CPU_TOTAL["$node"]:-0}
    local prev_idle=${PREV_CPU_IDLE["$node"]:-0}

    PREV_CPU_TOTAL["$node"]=$total
    PREV_CPU_IDLE["$node"]=$idle_all

    if (( prev_total == 0 )); then
        # First sample: cannot compute delta yet
        echo "n/a"
        return
    fi

    local delta_total=$(( total - prev_total ))
    local delta_idle=$(( idle_all - prev_idle ))
    if (( delta_total <= 0 )); then
        echo "n/a"
        return
    fi

    local delta_busy=$(( delta_total - delta_idle ))

    # CPU% = 100 * delta_busy / delta_total, with one decimal
    awk -v b="${delta_busy}" -v t="${delta_total}" '
        BEGIN {
            if (t <= 0) { print "n/a"; exit }
            v = (b * 100.0) / t;
            printf "%.1f%%", v;
        }
    '
}

# -----------------------------------------------------------------------------
# Local node probe
# -----------------------------------------------------------------------------

probe_local_node() {
    NODE_NAME=$(hostname)

    LOAD1=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "n/a")

    if [ -r /proc/meminfo ]; then
        MEM_FREE=$(awk "/MemFree:/ {printf \"%.0f\", \$2/1024}" /proc/meminfo)
        MEM_AVAIL=$(awk "/MemAvailable:/ {printf \"%.0f\", \$2/1024}" /proc/meminfo)
    else
        MEM_FREE="n/a"
        MEM_AVAIL="n/a"
    fi

    if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP_C=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
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

    # CPU stat line
    CPU_STAT_LINE=$(grep '^cpu ' /proc/stat 2>/dev/null || echo "")
    if [[ -n "${CPU_STAT_LINE}" ]]; then
        CPU_PCT=$(compute_cpu_usage "${NODE_NAME}" "${CPU_STAT_LINE#cpu }")
    else
        CPU_PCT="n/a"
    fi

    # Disk free on /
    DISK_FREE=$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}')
    [[ -z "${DISK_FREE}" ]] && DISK_FREE="n/a"

    echo "NODE=${NODE_NAME}"
    echo "LOAD1=${LOAD1}"
    echo "CPU_PCT=${CPU_PCT}"
    echo "MEM_FREE_MB=${MEM_FREE}"
    echo "MEM_AVAIL_MB=${MEM_AVAIL}"
    echo "TEMP_C=${TEMP_C}"
    echo "DISTCCD_ACTIVE=${DISTCCD_ACTIVE}"
    echo "DISTCC_JOB_COUNT=${DISTCC_JOB_COUNT}"
    echo "INCLUDE_SERVER_STATE=${INCLUDE_SERVER_STATE}"
    echo "K3S_SERVER_STATE=${K3S_SERVER_STATE}"
    echo "K3S_AGENT_STATE=${K3S_AGENT_STATE}"
    echo "DISK_FREE=${DISK_FREE}"
}

# -----------------------------------------------------------------------------
# Remote node probe
# -----------------------------------------------------------------------------

probe_remote_node() {
    local node="$1"

    ssh "${SSH_OPTS[@]}" "${node}" '
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

        CPU_STAT_LINE=$(grep "^cpu " /proc/stat 2>/dev/null || echo "")
        echo "CPU_STAT_LINE=${CPU_STAT_LINE}"

        DISK_FREE=$(df -BG / 2>/dev/null | awk "NR==2 {print \$4}")
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
    ' 2>/dev/null
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------

while true; do
    print_header

    printf "%-12s %-8s %-6s %-8s %-8s %-8s %-6s %-8s %-6s %-6s %-8s %-10s %-8s\n" \
        "Node" "Mode" "L1" "CPU%" "Free" "Avail" "Temp" "distccd" "Jobs" "Inc" "k3s" "k3s-agent" "DiskFree"

    echo "------------------------------------------------------------------------------------------------------------------------"

    WORKER_DISTCCD_ACTIVE="no"
    declare -A RAW_BY_NODE
    declare -A CPU_STAT_BY_NODE

    # First pass: gather data
    for node in "${ALL_NODES[@]}"; do
        if [[ "$node" == "$(hostname)" ]] || [[ "$node" == "$(hostname -f)" ]]; then
            RAW=$(probe_local_node)
            CPU_STAT_BY_NODE["$node"]=""  # local handled internally
        else
            RAW=$(probe_remote_node "${node}" || true)
        fi

        RAW_BY_NODE["$node"]="${RAW}"

        if [[ -n "${RAW}" ]]; then
            # Extract CPU_STAT_LINE if present (remote nodes)
            CPU_LINE=$(printf '%s\n' "${RAW}" | sed -n 's/^CPU_STAT_LINE=//p')
            if [[ -n "${CPU_LINE}" ]]; then
                CPU_STAT_BY_NODE["$node"]="${CPU_LINE#cpu }"
            fi

            eval "$(printf '%s\n' "${RAW}" | sed -n 's/^\([A-Z0-9_]*\)=\(.*\)$/\1="\2"/p')"
            if [[ "$node" != "${BUILDER_NODE}" && "${DISTCCD_ACTIVE}" == "active" ]]; then
                WORKER_DISTCCD_ACTIVE="yes"
            fi
        fi
    done

    # Second pass: render rows
    for node in "${ALL_NODES[@]}"; do
        RAW="${RAW_BY_NODE["$node"]}"

        if [[ -z "${RAW}" ]]; then
            printf "%-12s %-8s %-6s %-8s %-8s %-8s %-6s %-8s %-6s %-6s %-8s %-10s %-8s\n" \
                "${node}" "$(status_color offline)" "n/a" "n/a" "n/a" "n/a" "n/a" \
                "n/a" "n/a" "n/a" "n/a" "n/a" "n/a"
            continue
        fi

        eval "$(printf '%s\n' "${RAW}" | sed -n 's/^\([A-Z0-9_]*\)=\(.*\)$/\1="\2"/p')"

        # CPU% for remote nodes (compute from stored stat line)
        if [[ "$node" != "$(hostname)" && "$node" != "$(hostname -f)" ]]; then
            if [[ -n "${CPU_STAT_BY_NODE["$node"]}" ]]; then
                CPU_PCT=$(compute_cpu_usage "${NODE}" "${CPU_STAT_BY_NODE["$node"]}")
            else
                CPU_PCT="n/a"
            fi
        fi

        MODE_DISPLAY="unknown"
        if [[ "$node" == "${BUILDER_NODE}" ]]; then
            if [[ "${K3S_SERVER_STATE}" == "active" ]]; then
                MODE_DISPLAY="cluster"
            elif [[ "${WORKER_DISTCCD_ACTIVE}" == "yes" ]]; then
                MODE_DISPLAY="build"
            fi
        else
            if [[ "${K3S_AGENT_STATE}" == "active" ]]; then
                MODE_DISPLAY="cluster"
            elif [[ "${DISTCCD_ACTIVE}" == "active" ]]; then
                MODE_DISPLAY="build"
            fi
        fi

        printf "%-12s " "${NODE}"

        case "${MODE_DISPLAY}" in
            build)   printf "%-8s " "$(status_color build)" ;;
            cluster) printf "%-8s " "$(status_color cluster)" ;;
            *)       printf "%-8s " "${MODE_DISPLAY}" ;;
        esac

        printf "%-6s %-8s %-8s %-8s " \
            "${LOAD1}" \
            "${CPU_PCT}" \
            "${MEM_FREE_MB}" \
            "${MEM_AVAIL_MB}"

        printf "%-6s " "${TEMP_C}"
        printf "%-8s " "$(status_color "${DISTCCD_ACTIVE}")"
        printf "%-6s " "${DISTCC_JOB_COUNT}"
        printf "%-6s " "${INCLUDE_SERVER_STATE}"
        printf "%-8s " "$(status_color "${K3S_SERVER_STATE}")"
        printf "%-10s " "$(status_color "${K3S_AGENT_STATE}")"
        printf "%-8s\n" "${DISK_FREE}"
    done

    echo
    echo "Refresh interval: ${REFRESH_INTERVAL}s (Ctrl-C to exit)"
    sleep "${REFRESH_INTERVAL}"
done
