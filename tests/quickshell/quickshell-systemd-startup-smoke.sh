#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    [[ -f "$file" ]] || fail "$message (missing: $file)"
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    [[ "$haystack" == *"$needle"* ]] || fail "$message (missing: [$needle])"
}

assert_no_active_line() {
    local line="$1"
    local file="$2"
    local message="$3"

    if grep -Fxq "$line" "$file"; then
        fail "$message (unexpected active line: [$line])"
    fi
}

assert_matches() {
    local regex="$1"
    local text="$2"
    local message="$3"

    if ! grep -Eq "$regex" <<<"$text"; then
        fail "$message (pattern not found: [$regex])"
    fi
}

main() {
    local service_file
    local autostart_file
    local install_file
    local autostart_text
    local install_text

    service_file="$REPO_ROOT/config/systemd/user/quickshell.service"
    autostart_file="$REPO_ROOT/config/hypr/config/autostart.conf"
    install_file="$REPO_ROOT/install.sh"

    assert_file_exists "$service_file" "quickshell user service must be tracked in repo"
    assert_file_exists "$autostart_file" "Hyprland autostart config must exist"
    assert_file_exists "$install_file" "installer must exist"

    autostart_text="$(<"$autostart_file")"
    install_text="$(<"$install_file")"

    assert_matches '^\s*exec-once\s*=\s*systemctl --user restart quickshell\.service\s*\|\|\s*systemctl --user start quickshell\.service\s*$' "$autostart_text" "autostart must start quickshell through systemd user service"
    assert_contains "# exec-once = QT_LOGGING_RULES=\"quickshell.dbus.properties.warning=false;quickshell.service.notifications.warning=false;qt.svg.warning=false\" quickshell -p ~/.config/quickshell/shell.qml &" "$autostart_text" "direct quickshell launch must remain as commented fallback"
    assert_no_active_line "exec-once = QT_LOGGING_RULES=\"quickshell.dbus.properties.warning=false;quickshell.service.notifications.warning=false;qt.svg.warning=false\" quickshell -p ~/.config/quickshell/shell.qml &" "$autostart_file" "direct quickshell launch must not be active"
    assert_matches '^\s*if ! run systemctl --user restart quickshell\.service; then\s*$' "$install_text" "installer must guard quickshell restart failures"
    assert_matches '^\s*run systemctl --user start quickshell\.service\s*$' "$install_text" "installer must fall back to starting quickshell service"

    printf 'PASS: quickshell systemd startup smoke checks\n'
}

main "$@"
