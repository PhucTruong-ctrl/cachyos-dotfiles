#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GLOBAL_STATE_FILE="$REPO_DIR/config/quickshell/services/GlobalState.qml"
CONTROL_CENTER_FILE="$REPO_DIR/config/quickshell/components/ControlCenter.qml"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains_literal() {
    local needle="$1"
    local file="$2"
    local message="$3"

    if ! grep -Fq "$needle" "$file"; then
        fail "$message (missing: [$needle])"
    fi
}

assert_contains_regex() {
    local pattern="$1"
    local file="$2"
    local message="$3"

    if ! grep -Eq "$pattern" "$file"; then
        fail "$message (pattern: [$pattern])"
    fi
}

test_global_state_tracks_high_performance() {
    assert_contains_literal 'property bool highPerformanceActive: false' "$GLOBAL_STATE_FILE" 'GlobalState should define highPerformanceActive once'
}

test_control_center_has_performance_mode_processes() {
    assert_contains_literal 'sudo /usr/local/bin/performance-mode status' "$CONTROL_CENTER_FILE" 'ControlCenter should query helper status through sudo bridge'
    assert_contains_literal 'sudo /usr/local/bin/performance-mode on' "$CONTROL_CENTER_FILE" 'ControlCenter should enable helper through sudo bridge'
    assert_contains_literal 'sudo /usr/local/bin/performance-mode off' "$CONTROL_CENTER_FILE" 'ControlCenter should disable helper through sudo bridge'
}

test_status_parser_uses_exact_contract() {
    assert_contains_literal '"PERFORMANCE_MODE=on"' "$CONTROL_CENTER_FILE" 'ControlCenter should parse the exact helper status contract'
    assert_contains_regex 'GlobalState\.highPerformanceActive *= *\([^)]*trim\(\) *=== *"PERFORMANCE_MODE=on"\)' "$CONTROL_CENTER_FILE" 'ControlCenter should only set highPerformanceActive for exact on status'
}

test_status_process_uses_restart_pattern() {
    assert_contains_literal 'performanceModeStatus.running = false' "$CONTROL_CENTER_FILE" 'ControlCenter should force-stop status process before restart'
    assert_contains_literal 'performanceModeStatus.running = true' "$CONTROL_CENTER_FILE" 'ControlCenter should restart status process after reset'
}

main() {
    test_global_state_tracks_high_performance
    test_control_center_has_performance_mode_processes
    test_status_parser_uses_exact_contract
    test_status_process_uses_restart_pattern

    printf 'PASS: quickshell performance-mode bridge tests\n'
}

main "$@"
