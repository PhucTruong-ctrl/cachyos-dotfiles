#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
parser_script="$repo_root/config/quickshell/scripts/hyprland/get_keybinds.py"

tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

fixture_path="$tmp_dir/keybinds.conf"

cat >"$fixture_path" <<'EOF'
bindd = $mainMod, RETURN, Opens your preferred terminal emulator ($terminal), exec, $terminal

# ======= Quickshell Overlays =======
bindd = $mainMod, C, Opens the Quickshell calendar overlay, exec, qs ipc call toggle-calendar toggle

# ======= Window Actions =======
bindd = $mainMod, R, Activates window resizing mode, submap, resize
submap = resize
bindd = , right, Resize to the right (resizing mode), resizeactive, 15 0
bindd = , escape, Ends window resizing mode, submap, reset
submap = reset

bindel = , XF86AudioRaiseVolume, exec, pamixer -i 5
EOF

json_output="$(python "$parser_script" --path "$fixture_path")"

JSON_OUTPUT="$json_output" python - <<'PY'
import json
import os
import sys

items = json.loads(os.environ["JSON_OUTPUT"])

assert isinstance(items, list), "parser output must be a JSON array"
assert len(items) == 5, f"expected 5 bindd entries, got {len(items)}"

for item in items:
    assert sorted(item.keys()) == ["command", "description", "dispatcher", "key", "mods", "section", "submap"], item
    assert isinstance(item["mods"], list), item
    assert isinstance(item["key"], str), item
    assert isinstance(item["description"], str), item
    assert isinstance(item["dispatcher"], str), item
    assert isinstance(item["command"], str), item
    assert isinstance(item["section"], str), item
    assert item["submap"] is None or isinstance(item["submap"], str), item

by_description = {item["description"]: item for item in items}

assert by_description["Opens your preferred terminal emulator ($terminal)"] == {
    "mods": ["$mainMod"],
    "key": "RETURN",
    "description": "Opens your preferred terminal emulator ($terminal)",
    "dispatcher": "exec",
    "command": "$terminal",
    "section": "General",
    "submap": None,
}

assert by_description["Opens the Quickshell calendar overlay"] == {
    "mods": ["$mainMod"],
    "key": "C",
    "description": "Opens the Quickshell calendar overlay",
    "dispatcher": "exec",
    "command": "qs ipc call toggle-calendar toggle",
    "section": "Quickshell Overlays",
    "submap": None,
}

assert by_description["Activates window resizing mode"] == {
    "mods": ["$mainMod"],
    "key": "R",
    "description": "Activates window resizing mode",
    "dispatcher": "submap",
    "command": "resize",
    "section": "Window Actions",
    "submap": None,
}

assert by_description["Resize to the right (resizing mode)"] == {
    "mods": [],
    "key": "right",
    "description": "Resize to the right (resizing mode)",
    "dispatcher": "resizeactive",
    "command": "15 0",
    "section": "Window Actions",
    "submap": "resize",
}

assert by_description["Ends window resizing mode"] == {
    "mods": [],
    "key": "escape",
    "description": "Ends window resizing mode",
    "dispatcher": "submap",
    "command": "reset",
    "section": "Window Actions",
    "submap": "resize",
}
PY
