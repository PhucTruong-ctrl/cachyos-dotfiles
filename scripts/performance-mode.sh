#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s {on|off|status}\n' "$0" >&2
}

warn() {
    printf 'WARNING: %s\n' "$1" >&2
}

probe_backend_status() {
    local backend="$1"
    local output

    if ! output="$("$backend" status 2>/dev/null)"; then
        return 1
    fi

    case "$output" in
        PERFORMANCE_MODE=on|PERFORMANCE_MODE=off)
            printf '%s\n' "$output"
            ;;
        *)
            return 1
            ;;
    esac
}

find_backend() {
    local backend
    local output

    for backend in "${BACKEND_CANDIDATES[@]}"; do
        [[ -n "$backend" && -x "$backend" ]] || continue

        if output="$(probe_backend_status "$backend")"; then
            SELECTED_BACKEND="$backend"
            SELECTED_BACKEND_STATUS="$output"
            return 0
        fi
    done

    return 1
}

write_cpu_value() {
    local file="$1"
    local value="$2"

    if [[ -e "$file" ]]; then
        printf '%s\n' "$value" > "$file"
        return 0
    fi

    warn "intel_pstate file unavailable: $file"
}

set_internal_mode() {
    local mode="$1"
    local max_perf_file="$INTEL_PSTATE_DIR/max_perf_pct"
    local no_turbo_file="$INTEL_PSTATE_DIR/no_turbo"

    case "$mode" in
        on)
            write_cpu_value "$max_perf_file" 100
            write_cpu_value "$no_turbo_file" 0

            if [[ -x "$NVIDIA_SMI" ]]; then
                "$NVIDIA_SMI" --reset-gpu-clocks
            fi
            ;;
        off)
            write_cpu_value "$max_perf_file" 80
            write_cpu_value "$no_turbo_file" 1

            if [[ -x "$NVIDIA_SMI" ]]; then
                "$NVIDIA_SMI" --lock-gpu-clocks=0,1101
            fi
            ;;
    esac
}

print_internal_status() {
    local max_perf_file="$INTEL_PSTATE_DIR/max_perf_pct"
    local no_turbo_file="$INTEL_PSTATE_DIR/no_turbo"
    local mode="off"
    local max_perf
    local no_turbo

    if [[ ! -e "$max_perf_file" ]]; then
        warn "intel_pstate file unavailable: $max_perf_file"
    fi

    if [[ ! -e "$no_turbo_file" ]]; then
        warn "intel_pstate file unavailable: $no_turbo_file"
    fi

    if [[ -e "$max_perf_file" && -e "$no_turbo_file" ]]; then
        max_perf="$(<"$max_perf_file")"
        no_turbo="$(<"$no_turbo_file")"

        if [[ "$max_perf" == "100" && "$no_turbo" == "0" ]]; then
            mode="on"
        fi
    fi

    printf 'PERFORMANCE_MODE=%s\n' "$mode"
}

COMMAND="${1:-}"

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

case "$COMMAND" in
    on|off|status)
        ;;
    *)
        usage
        exit 1
        ;;
esac

INTEL_PSTATE_DIR="${PERFORMANCE_MODE_INTEL_PSTATE_DIR:-/sys/devices/system/cpu/intel_pstate}"
NVIDIA_SMI="${PERFORMANCE_MODE_NVIDIA_SMI:-/usr/bin/nvidia-smi}"
BACKENDS_RAW="${PERFORMANCE_MODE_BACKENDS:-/usr/local/bin/game-performance:/usr/local/bin/performance-backend}"
BACKEND_CANDIDATES=()
SELECTED_BACKEND=""
SELECTED_BACKEND_STATUS=""

if [[ -n "$BACKENDS_RAW" ]]; then
    IFS=':' read -r -a BACKEND_CANDIDATES <<< "$BACKENDS_RAW"
fi

if find_backend; then
    if [[ "$COMMAND" == "status" ]]; then
        printf '%s\n' "$SELECTED_BACKEND_STATUS"
    else
        "$SELECTED_BACKEND" "$COMMAND"
    fi
    exit 0
fi

case "$COMMAND" in
    on|off)
        set_internal_mode "$COMMAND"
        ;;
    status)
        print_internal_status
        ;;
esac
