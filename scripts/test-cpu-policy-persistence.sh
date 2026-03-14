#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TLP_CONF="$REPO_ROOT/etc/tlp.conf"

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

read_key() {
    local key="$1"
    local line

    line="$(grep -E "^${key}=" "$TLP_CONF" || true)"
    [[ -n "$line" ]] || fail "missing key in etc/tlp.conf: $key"
    printf '%s' "${line#*=}"
}

main() {
    [[ -f "$TLP_CONF" ]] || fail "etc/tlp.conf not found"

    assert_eq "performance" "$(read_key CPU_SCALING_GOVERNOR_ON_AC)" "AC governor must persist performance"
    assert_eq "power" "$(read_key CPU_ENERGY_PERF_POLICY_ON_BAT)" "BAT policy must persist power"
    assert_eq "performance" "$(read_key CPU_ENERGY_PERF_POLICY_ON_AC)" "AC policy must persist performance"
    assert_eq "100" "$(read_key CPU_MAX_PERF_ON_AC)" "AC max perf must persist 100"
    assert_eq "1" "$(read_key CPU_BOOST_ON_AC)" "AC boost must persist enabled"
    assert_eq "60" "$(read_key CPU_MAX_PERF_ON_BAT)" "BAT max perf must persist 60"
    assert_eq "0" "$(read_key CPU_BOOST_ON_BAT)" "BAT boost must persist disabled"

    printf 'PASS: cpu policy persistence smoke checks\n'
}

main "$@"
