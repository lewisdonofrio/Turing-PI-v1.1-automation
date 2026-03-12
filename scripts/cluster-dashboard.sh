#!/bin/bash
set -euo pipefail

# --- Config ---
REFRESH=5

# --- Colors (high contrast, theme-friendly) ---
RED="\033[31m"
YELLOW="\033[33m"
GREEN="\033[32m"
CYAN="\033[96m"
WHITE="\033[97m"
RESET="\033[0m"

# --- Helpers ---
colorize() {
    case "$1" in
        ok|Running|True|Ready|control-plane-ready) echo -e "${GREEN}$1${RESET}" ;;
        not-ready|False|CrashLoopBackOff|Error|Failed|Unknown|control-plane-down) echo -e "${RED}$1${RESET}" ;;
        *) echo -e "${YELLOW}$1${RESET}" ;;
    esac
}

bar() {
    local value=$1
    local max=$2
    local width=${3:-20}

    if [ "$max" -le 0 ]; then
        printf "[%0.s░" $(seq 1 "$width")
        printf "] 0%%"
        return
    fi

    local percent=$(( value * 100 / max ))
    [ "$percent" -gt 100 ] && percent=100
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))

    printf "["
    printf "%0.s█" $(seq 1 $filled)
    printf "%0.s░" $(seq 1 $empty)
    printf "] %s%%" "$percent"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

while true; do
    clear
    echo -e "${CYAN}=== CLUSTER OPERATIONS COCKPIT ===${RESET}"
    echo

    # --- CONTROL PLANE ---
    PID="$(pgrep -x k3s || true)"
    READYZ="$(kubectl get --raw='/readyz' 2>/dev/null || echo 'fail')"
    LIVEZ="$(kubectl get --raw='/livez' 2>/dev/null || echo 'fail')"
    VERBOSE_READY="$(kubectl get --raw='/readyz?verbose=1' 2>/dev/null || true)"

    SCHED_READY=$(echo "$VERBOSE_READY" | grep -q 'scheduler.*ok' && echo ok || echo not-ready)
    CTRL_READY=$(echo "$VERBOSE_READY" | grep -q 'controller-manager.*ok' && echo ok || echo not-ready)

    echo -e "${CYAN}CONTROL PLANE${RESET}"
    if [ -n "$PID" ]; then
        echo -e "k3s-server: $(colorize RUNNING) (PID $PID)"
    else
        if [[ "$READYZ" == "ok" || "$LIVEZ" == "ok" ]]; then
            echo -e "k3s-server: $(colorize RUNNING) (PID fallback)"
        else
            echo -e "k3s-server: $(colorize NOT-RUNNING)"
        fi
    fi
    echo -e "API readyz: $(colorize "$READYZ")"
    echo -e "API livez:  $(colorize "$LIVEZ")"
    echo -e "scheduler:  $(colorize "$SCHED_READY")"
    echo -e "controller-manager: $(colorize "$CTRL_READY")"
    echo

# --- NODE RESOURCES (Two-column, per-node pressure, cluster memory bar) ---
echo -e "${CYAN}NODE RESOURCES${RESET}"

# Gather node info
mapfile -t NODE_NAMES < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
mapfile -t READY < <(kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}')
mapfile -t MEMP < <(kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="MemoryPressure")].status}{"\n"}{end}')
mapfile -t DISKP < <(kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="DiskPressure")].status}{"\n"}{end}')

# --- Cluster-wide memory (requires metrics-server) ---
if kubectl top nodes >/dev/null 2>&1; then
    TOTAL_ALLOC_Ki=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.allocatable.memory}{"\n"}{end}' \
        | sed 's/Ki//' | awk '{sum+=$1} END {print sum}')

    TOTAL_USED_Ki=$(kubectl top nodes --no-headers | awk '{gsub("Mi","",$4); sum+=$4} END {print sum*1024}')

    if [[ -n "$TOTAL_ALLOC_Ki" && -n "$TOTAL_USED_Ki" ]]; then
        echo -e "CLUSTER MEMORY"
        bar "$TOTAL_USED_Ki" "$TOTAL_ALLOC_Ki" 30
        printf "  (%.1f GiB / %.1f GiB)\n\n" \
            "$(echo "$TOTAL_USED_Ki / 1048576" | bc -l)" \
            "$(echo "$TOTAL_ALLOC_Ki / 1048576" | bc -l)"
    else
        echo -e "CLUSTER MEMORY: metrics unavailable\n"
    fi
else
    echo -e "CLUSTER MEMORY: metrics-server not installed\n"
fi

# --- Two-column per-node health ---
TOTAL=${#NODE_NAMES[@]}
HALF=$(( (TOTAL + 1) / 2 ))

for ((i=0; i<HALF; i++)); do
    L=$i
    R=$((i + HALF))

    LEFT=$(printf "%-12s Ready:%-5s MemP:%-5s DiskP:%-5s" \
        "${NODE_NAMES[$L]}" \
        "$(colorize "${READY[$L]}")" \
        "$(colorize "${MEMP[$L]}")" \
        "$(colorize "${DISKP[$L]}")")

    if [[ $R -lt $TOTAL ]]; then
        RIGHT=$(printf "%-12s Ready:%-5s MemP:%-5s DiskP:%-5s" \
            "${NODE_NAMES[$R]}" \
            "$(colorize "${READY[$R]}")" \
            "$(colorize "${MEMP[$R]}")" \
            "$(colorize "${DISKP[$R]}")")

        printf "%-55s %s\n" "$LEFT" "$RIGHT"
    else
        printf "%s\n" "$LEFT"
    fi
done

echo

    # --- POD COUNTS PER NODE ---
    echo -e "${CYAN}POD COUNTS PER NODE${RESET}"
    kubectl get pods -A -o json 2>/dev/null \
      | jq -r '.items[] | .spec.nodeName // "none"' \
      | sort | uniq -c \
      | awk '{printf "  %s: %s pods\n", $2, $1}'
    echo

    # --- PER-NAMESPACE SUMMARY ---
    echo -e "${CYAN}NAMESPACE SUMMARY${RESET}"
    kubectl get pods -A --no-headers 2>/dev/null \
      | awk '{print $1}' \
      | sort | uniq -c \
      | awk '{printf "  %s: %s pods\n", $2, $1}'
    echo

    # --- POD TABLE ---
    echo -e "${CYAN}PODS (ALL NAMESPACES)${RESET}"
    kubectl get pods -A -o wide --sort-by=.spec.nodeName
    echo

    # --- PROBLEM PODS (escape-safe, per-line color) ---
    echo -e "${CYAN}PROBLEM PODS${RESET}"
    problems=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4 != "Running"' || true)

    if [ -n "$problems" ]; then
        echo "$problems" | while read -r line; do
            [ -n "$line" ] && echo -e "${RED}${line}${RESET}"
        done
    else
        echo -e "${GREEN}No issues detected${RESET}"
    fi

    echo

    # --- STAGE ESTIMATE ---
    echo -e "${CYAN}STAGE ESTIMATE${RESET}"
    if [[ "$READYZ" != "ok" ]]; then
        echo -e "$(colorize control-plane-down)"
    elif [[ "$SCHED_READY" != "ok" || "$CTRL_READY" != "ok" ]]; then
        echo -e "$(colorize control-plane-warming-up)"
    else
        echo -e "$(colorize control-plane-ready)"
    fi

    echo
    echo "Refreshing in ${REFRESH}s..."
    sleep "$REFRESH"
done
