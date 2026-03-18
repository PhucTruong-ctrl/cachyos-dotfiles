#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s {on|off|status}\n' "$0" >&2
}

warn() {
    printf 'WARNING: %s\n' "$1" >&2
}

STATE_FILE="${PERFORMANCE_MODE_STATE_FILE:-/run/performance-mode.state}"

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

write_cpufreq_limit() {
    local limit_khz="$1"
    local policy_dir
    local scaling_max_file
    local wrote_any=0

    for policy_dir in "$CPUFREQ_DIR"/policy*; do
        [[ -d "$policy_dir" ]] || continue
        scaling_max_file="$policy_dir/scaling_max_freq"
        [[ -e "$scaling_max_file" ]] || continue
        if ! printf '%s\n' "$limit_khz" > "$scaling_max_file"; then
            warn "failed to write cpufreq cap: $scaling_max_file"
            continue
        fi
        wrote_any=1
    done

    if [[ "$wrote_any" -eq 0 ]]; then
        warn "cpufreq scaling_max_freq unavailable under: $CPUFREQ_DIR"
    fi
}

reset_cpufreq_limit() {
    local policy_dir
    local scaling_max_file
    local cpuinfo_max_file
    local max_khz
    local wrote_any=0

    for policy_dir in "$CPUFREQ_DIR"/policy*; do
        [[ -d "$policy_dir" ]] || continue
        scaling_max_file="$policy_dir/scaling_max_freq"
        cpuinfo_max_file="$policy_dir/cpuinfo_max_freq"
        [[ -e "$scaling_max_file" && -e "$cpuinfo_max_file" ]] || continue
        max_khz="$(<"$cpuinfo_max_file")"
        [[ -n "$max_khz" ]] || continue
        if ! printf '%s\n' "$max_khz" > "$scaling_max_file"; then
            warn "failed to reset cpufreq cap: $scaling_max_file"
            continue
        fi
        wrote_any=1
    done

    if [[ "$wrote_any" -eq 0 ]]; then
        warn "cpufreq cpuinfo_max_freq unavailable under: $CPUFREQ_DIR"
    fi
}

set_internal_mode() {
    local mode="$1"
    local max_perf_file="$INTEL_PSTATE_DIR/max_perf_pct"
    local no_turbo_file="$INTEL_PSTATE_DIR/no_turbo"
    local hwp_boost_file="$INTEL_PSTATE_DIR/hwp_dynamic_boost"

    case "$mode" in
        on)
            # Stop TLP while high performance mode is active; otherwise TLP can
            # immediately re-apply low-heat caps on AC/BAT events.
            if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet tlp 2>/dev/null; then
                systemctl stop tlp || warn "failed to stop tlp; performance caps may be reverted"
            fi

            write_cpu_value "$max_perf_file" 100
            write_cpu_value "$no_turbo_file" 0
            write_cpu_value "$hwp_boost_file" 1
            write_cpufreq_limit "$ON_CPU_CAP_KHZ"

            if [[ -x "$NVIDIA_SMI" ]]; then
                "$NVIDIA_SMI" --reset-gpu-clocks 2>/dev/null || warn "failed to reset NVIDIA clocks"
            fi

            mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
            printf 'on\n' > "$STATE_FILE" || warn "failed to persist state file: $STATE_FILE"
            ;;
        off)
            write_cpu_value "$max_perf_file" 80
            write_cpu_value "$no_turbo_file" 1
            write_cpu_value "$hwp_boost_file" 0
            write_cpufreq_limit "$OFF_CPU_CAP_KHZ"

            if [[ -x "$NVIDIA_SMI" ]]; then
                "$NVIDIA_SMI" --lock-gpu-clocks=0,1101 2>/dev/null || warn "failed to lock NVIDIA clocks"
            fi

            # Restore TLP-managed low-heat baseline on OFF.
            if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled --quiet tlp 2>/dev/null; then
                systemctl start tlp || warn "failed to start tlp"
                if command -v tlp >/dev/null 2>&1; then
                    tlp start >/dev/null 2>&1 || warn "failed to apply tlp baseline"
                fi
            fi

            mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
            printf 'off\n' > "$STATE_FILE" || warn "failed to persist state file: $STATE_FILE"
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

    if [[ -e "$STATE_FILE" ]]; then
        case "$(<"$STATE_FILE")" in
            on|off)
                mode="$(<"$STATE_FILE")"
                printf 'PERFORMANCE_MODE=%s\n' "$mode"
                return
                ;;
        esac
    fi

    if [[ -e "$max_perf_file" && -e "$no_turbo_file" ]]; then
        max_perf="$(<"$max_perf_file")"
        no_turbo="$(<"$no_turbo_file")"

        if [[ "$no_turbo" == "0" && "$max_perf" -ge 95 ]]; then
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
CPUFREQ_DIR="${PERFORMANCE_MODE_CPUFREQ_DIR:-/sys/devices/system/cpu/cpufreq}"
OFF_CPU_CAP_KHZ="${PERFORMANCE_MODE_OFF_CAP_KHZ:-1000000}"
ON_CPU_CAP_KHZ="${PERFORMANCE_MODE_ON_CAP_KHZ:-2600000}"
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
