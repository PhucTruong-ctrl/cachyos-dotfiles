#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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

assert_python_regex() {
    local pattern="$1"
    local file="$2"
    local message="$3"

    if ! python3 - "$pattern" "$file" <<'PY'
import pathlib
import re
import sys

pattern = sys.argv[1]
file_path = pathlib.Path(sys.argv[2])
text = file_path.read_text()
sys.exit(0 if re.search(pattern, text, re.S) else 1)
PY
    then
        fail "$message (pattern: [$pattern])"
    fi
}

test_toggle_button_supports_warning_active_styling() {
    assert_contains_literal 'property color activeColor: GlobalState.matugenPrimary' "$CONTROL_CENTER_FILE" 'ToggleButton should allow overriding the active fill color'
    assert_contains_literal 'property color activeBorderColor: GlobalState.lavender' "$CONTROL_CENTER_FILE" 'ToggleButton should allow overriding the active border color'
    assert_contains_literal 'property color activeForegroundColor: GlobalState.matugenOnPrimary' "$CONTROL_CENTER_FILE" 'ToggleButton should allow overriding the active foreground color'
}

test_high_performance_toggle_is_present() {
    assert_contains_literal 'labelText: "High Performance"' "$CONTROL_CENTER_FILE" 'ControlCenter should expose a High Performance toggle'
    assert_contains_literal 'active:    GlobalState.highPerformanceActive' "$CONTROL_CENTER_FILE" 'High Performance toggle should bind to GlobalState.highPerformanceActive'
    assert_contains_literal 'activeColor: GlobalState.warning' "$CONTROL_CENTER_FILE" 'High Performance toggle should use warning styling when active'
    assert_contains_literal 'activeForegroundColor: GlobalState.base' "$CONTROL_CENTER_FILE" 'High Performance toggle should keep warning text readable'
}

test_high_performance_toggle_uses_manual_onoff_semantics() {
    assert_python_regex 'if \(GlobalState\.highPerformanceActive\) \{\s*performanceModeOff\.running = false\s*performanceModeOff\.running = true\s*\} else \{\s*performanceModeOn\.running = false\s*performanceModeOn\.running = true\s*\}\s*GlobalState\.highPerformanceActive = !GlobalState\.highPerformanceActive' "$CONTROL_CENTER_FILE" 'High Performance toggle should run explicit off/on commands and optimistically flip state'
}

test_toggle_processes_reconcile_with_status_refresh() {
    assert_python_regex 'id:\s+performanceModeOn.*?onExited:\s*refreshPerformanceModeStatus\(\)' "$CONTROL_CENTER_FILE" 'Enable process should refresh helper status after exit'
    assert_python_regex 'id:\s+performanceModeOff.*?onExited:\s*refreshPerformanceModeStatus\(\)' "$CONTROL_CENTER_FILE" 'Disable process should refresh helper status after exit'
}

main() {
    test_toggle_button_supports_warning_active_styling
    test_high_performance_toggle_is_present
    test_high_performance_toggle_uses_manual_onoff_semantics
    test_toggle_processes_reconcile_with_status_refresh

    printf 'PASS: control center high-performance button tests\n'
}

main "$@"
