#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUDOERS_FILE="$REPO_DIR/etc/sudoers.d/quickshell-performance-mode"
INSTALLER_FILE="$REPO_DIR/install.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        fail "$message (missing: [$needle])"
    fi
}

assert_not_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        fail "$message (unexpected: [$needle])"
    fi
}

test_sudoers_policy_is_least_privilege() {
    local content

    [[ -f "$SUDOERS_FILE" ]] || fail "sudoers policy file missing"
    content="$(<"$SUDOERS_FILE")"

    assert_contains "%wheel ALL=(root) NOPASSWD: /usr/local/bin/performance-mode on, /usr/local/bin/performance-mode off, /usr/local/bin/performance-mode status" "$content" "sudoers policy should allow only the three performance-mode commands"
    assert_not_contains "NOPASSWD: ALL" "$content" "sudoers policy must not allow all commands"
    assert_not_contains "*" "$content" "sudoers policy must not contain wildcard escalation"
}

test_installer_deploys_and_validates_bridge() {
    local content
    local helper_copy_line
    local sudoers_copy_line

    content="$(<"$INSTALLER_FILE")"
    helper_copy_line="run sudo cp \"\$SCRIPT_DIR/scripts/performance-mode.sh\" /usr/local/bin/performance-mode"
    sudoers_copy_line="run sudo cp \"\$SCRIPT_DIR/etc/sudoers.d/quickshell-performance-mode\" /etc/sudoers.d/quickshell-performance-mode"

    assert_contains "$helper_copy_line" "$content" "installer should deploy performance helper"
    assert_contains 'run sudo chmod 0755 /usr/local/bin/performance-mode' "$content" "installer should make performance helper executable"
    assert_contains 'run sudo mkdir -p /etc/sudoers.d' "$content" "installer should ensure sudoers.d exists"
    assert_contains "$sudoers_copy_line" "$content" "installer should deploy sudoers policy"
    assert_contains 'run sudo chmod 0440 /etc/sudoers.d/quickshell-performance-mode' "$content" "installer should lock down sudoers permissions"
    assert_contains 'run sudo visudo -cf /etc/sudoers.d/quickshell-performance-mode' "$content" "installer should validate deployed sudoers policy"
}

main() {
    test_sudoers_policy_is_least_privilege
    test_installer_deploys_and_validates_bridge

    printf 'PASS: installer performance-mode wiring tests\n'
}

main "$@"
