#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
parser_script="$repo_root/config/quickshell/scripts/hyprland/get_keybinds.py"
service_qml="$repo_root/config/quickshell/services/KeybindsService.qml"
services_qmldir="$repo_root/config/quickshell/services/qmldir"

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

SERVICE_QML="$service_qml" SERVICES_QMLDIR="$services_qmldir" python - <<'PY'
from pathlib import Path
import os
import re

service_text = Path(os.environ["SERVICE_QML"]).read_text(encoding="utf-8")
qmldir_text = Path(os.environ["SERVICES_QMLDIR"]).read_text(encoding="utf-8")

assert "pragma Singleton" in service_text, "KeybindsService must be a singleton"
assert re.search(r"property\s+var\s+keybinds\s*:\s*\[\]", service_text), "KeybindsService must expose property var keybinds: []"
assert "Process {" in service_text, "KeybindsService must define a Process"
assert "python" in service_text, "KeybindsService process should invoke python"
assert "get_keybinds.py" in service_text, "KeybindsService must call get_keybinds.py"
assert "onRead:" in service_text and "JSON.parse" in service_text, "KeybindsService must parse JSON in onRead"
assert "root.keybinds = []" in service_text, "KeybindsService must fall back to an empty array"
assert "import Quickshell.Hyprland" in service_text, "KeybindsService must import Quickshell.Hyprland for reactive reloads"
assert "Connections {" in service_text and "onRawEvent" in service_text, "KeybindsService must react to Hyprland events"
assert "configreloaded" in service_text, "KeybindsService must reload on Hyprland config reload"
assert "singleton KeybindsService 1.0 KeybindsService.qml" in qmldir_text, "qmldir must register KeybindsService"
PY
