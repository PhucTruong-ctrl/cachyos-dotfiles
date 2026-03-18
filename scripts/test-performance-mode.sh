#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/performance-mode.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$actual" != "$expected" ]]; then
        fail "$message (expected: [$expected], actual: [$actual])"
    fi
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        fail "$message (missing: [$needle], got: [$haystack])"
    fi
}

assert_file_value() {
    local file="$1"
    local expected="$2"
    local message="$3"
    local actual

    actual="$(<"$file")"
    assert_eq "$expected" "$actual" "$message"
}

run_cmd() {
    local stdout_file
    local stderr_file

    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    set +e
    "$@" >"$stdout_file" 2>"$stderr_file"
    RUN_STATUS=$?
    set -e

    RUN_STDOUT="$(<"$stdout_file")"
    RUN_STDERR="$(<"$stderr_file")"

    rm -f "$stdout_file" "$stderr_file"
}

make_fake_nvidia_smi() {
    local path="$1"
    local log_file="$2"

    cat <<EOF >"$path"
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$log_file"
EOF
    chmod +x "$path"
}

make_fake_backend() {
    local path="$1"
    local behavior="$2"
    local log_file="$3"

    cat <<EOF >"$path"
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$1" >> "$log_file"

case "\${1:-}" in
    status)
        printf '%s\n' "$behavior"
        ;;
    on|off)
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$path"
}

test_invalid_arg() {
    run_cmd bash "$TARGET" nope

    [[ -f "$TARGET" ]] || fail "performance helper missing"
    [[ $RUN_STATUS -ne 0 ]] || fail "invalid arg should return non-zero"
    assert_contains "Usage:" "$RUN_STDERR" "invalid arg should print usage to stderr"
}

test_status_contract_internal() {
    local temp_dir pstate_dir

    temp_dir="$(mktemp -d)"
    pstate_dir="$temp_dir/intel_pstate"
    mkdir -p "$pstate_dir"
    printf '100\n' >"$pstate_dir/max_perf_pct"
    printf '0\n' >"$pstate_dir/no_turbo"

    run_cmd env PERFORMANCE_MODE_INTEL_PSTATE_DIR="$pstate_dir" PERFORMANCE_MODE_BACKENDS="" bash "$TARGET" status

    assert_eq 0 "$RUN_STATUS" "status should succeed"
    assert_eq "PERFORMANCE_MODE=on" "$RUN_STDOUT" "status should emit exact contract"
    assert_eq "" "$RUN_STDERR" "status should not warn when pstate files exist"

    rm -rf "$temp_dir"
}

test_on_runtime_changes() {
    local temp_dir pstate_dir cpufreq_dir policy_dir nvidia_path nvidia_log

    temp_dir="$(mktemp -d)"
    pstate_dir="$temp_dir/intel_pstate"
    cpufreq_dir="$temp_dir/cpufreq"
    policy_dir="$cpufreq_dir/policy0"
    nvidia_path="$temp_dir/nvidia-smi"
    nvidia_log="$temp_dir/nvidia.log"
    mkdir -p "$pstate_dir"
    mkdir -p "$policy_dir"
    printf '80\n' >"$pstate_dir/max_perf_pct"
    printf '1\n' >"$pstate_dir/no_turbo"
    printf '1000000\n' >"$policy_dir/scaling_max_freq"
    printf '3400000\n' >"$policy_dir/cpuinfo_max_freq"
    make_fake_nvidia_smi "$nvidia_path" "$nvidia_log"

    run_cmd env PERFORMANCE_MODE_INTEL_PSTATE_DIR="$pstate_dir" PERFORMANCE_MODE_CPUFREQ_DIR="$cpufreq_dir" PERFORMANCE_MODE_NVIDIA_SMI="$nvidia_path" PERFORMANCE_MODE_BACKENDS="" bash "$TARGET" on

    assert_eq 0 "$RUN_STATUS" "on should succeed"
    assert_file_value "$pstate_dir/max_perf_pct" "100" "on should set max perf to 100"
    assert_file_value "$pstate_dir/no_turbo" "0" "on should enable turbo"
    assert_file_value "$policy_dir/scaling_max_freq" "2600000" "on should cap cpufreq to 2600000 kHz for sustained performance"
    assert_file_value "$nvidia_log" "--reset-gpu-clocks" "on should reset gpu clocks"

    rm -rf "$temp_dir"
}

test_off_runtime_changes() {
    local temp_dir pstate_dir cpufreq_dir policy_dir nvidia_path nvidia_log

    temp_dir="$(mktemp -d)"
    pstate_dir="$temp_dir/intel_pstate"
    cpufreq_dir="$temp_dir/cpufreq"
    policy_dir="$cpufreq_dir/policy0"
    nvidia_path="$temp_dir/nvidia-smi"
    nvidia_log="$temp_dir/nvidia.log"
    mkdir -p "$pstate_dir"
    mkdir -p "$policy_dir"
    printf '100\n' >"$pstate_dir/max_perf_pct"
    printf '0\n' >"$pstate_dir/no_turbo"
    printf '3400000\n' >"$policy_dir/scaling_max_freq"
    printf '3400000\n' >"$policy_dir/cpuinfo_max_freq"
    make_fake_nvidia_smi "$nvidia_path" "$nvidia_log"

    run_cmd env PERFORMANCE_MODE_INTEL_PSTATE_DIR="$pstate_dir" PERFORMANCE_MODE_CPUFREQ_DIR="$cpufreq_dir" PERFORMANCE_MODE_NVIDIA_SMI="$nvidia_path" PERFORMANCE_MODE_BACKENDS="" bash "$TARGET" off

    assert_eq 0 "$RUN_STATUS" "off should succeed"
    assert_file_value "$pstate_dir/max_perf_pct" "80" "off should restore max perf to 80"
    assert_file_value "$pstate_dir/no_turbo" "1" "off should disable turbo"
    assert_file_value "$policy_dir/scaling_max_freq" "1000000" "off should cap cpufreq to 1000000 kHz"
    assert_file_value "$nvidia_log" "--lock-gpu-clocks=0,1101" "off should restore gpu clock cap"

    rm -rf "$temp_dir"
}

test_missing_pstate_warns_but_continues() {
    local temp_dir nvidia_path nvidia_log

    temp_dir="$(mktemp -d)"
    nvidia_path="$temp_dir/nvidia-smi"
    nvidia_log="$temp_dir/nvidia.log"
    make_fake_nvidia_smi "$nvidia_path" "$nvidia_log"

    run_cmd env PERFORMANCE_MODE_INTEL_PSTATE_DIR="$temp_dir/missing" PERFORMANCE_MODE_NVIDIA_SMI="$nvidia_path" PERFORMANCE_MODE_BACKENDS="" bash "$TARGET" on

    assert_eq 0 "$RUN_STATUS" "on should continue when intel pstate is unavailable"
    assert_contains "intel_pstate" "$RUN_STDERR" "missing intel pstate should warn"
    assert_file_value "$nvidia_log" "--reset-gpu-clocks" "gpu step should still run when pstate files are missing"

    rm -rf "$temp_dir"
}

test_backend_priority_and_status_contract() {
    local temp_dir backend_one backend_two backend_log_one backend_log_two

    temp_dir="$(mktemp -d)"
    backend_one="$temp_dir/game-performance"
    backend_two="$temp_dir/performance-backend"
    backend_log_one="$temp_dir/backend-one.log"
    backend_log_two="$temp_dir/backend-two.log"

    make_fake_backend "$backend_one" "PERFORMANCE_MODE=off" "$backend_log_one"
    make_fake_backend "$backend_two" "PERFORMANCE_MODE=on" "$backend_log_two"

    run_cmd env PERFORMANCE_MODE_BACKENDS="$backend_one:$backend_two" bash "$TARGET" status

    assert_eq 0 "$RUN_STATUS" "backend status should succeed"
    assert_eq "PERFORMANCE_MODE=off" "$RUN_STDOUT" "first supported backend should win"
    assert_file_value "$backend_log_one" "status" "first backend should receive status"
    [[ ! -e "$backend_log_two" ]] || fail "second backend should not be used when first backend succeeds"

    rm -rf "$temp_dir"
}

main() {
    test_invalid_arg
    test_status_contract_internal
    test_on_runtime_changes
    test_off_runtime_changes
    test_missing_pstate_warns_but_continues
    test_backend_priority_and_status_contract

    printf 'PASS: performance-mode helper tests\n'
}

main "$@"
