#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

cheatsheet_qml="$repo_root/config/quickshell/components/Cheatsheet.qml"
shell_qml="$repo_root/config/quickshell/shell.qml"
popup_state_qml="$repo_root/config/quickshell/services/PopupStateService.qml"
keybinds_service_qml="$repo_root/config/quickshell/services/KeybindsService.qml"
keybinds_conf="$repo_root/config/hypr/config/keybinds.conf"
readme_path="$repo_root/README.md"

CHEATSHEET_QML="$cheatsheet_qml" \
SHELL_QML="$shell_qml" \
POPUP_STATE_QML="$popup_state_qml" \
KEYBINDS_SERVICE_QML="$keybinds_service_qml" \
KEYBINDS_CONF="$keybinds_conf" \
README_PATH="$readme_path" \
python - <<'PY'
from pathlib import Path
import os
import re

cheatsheet_path = Path(os.environ["CHEATSHEET_QML"])
shell_path = Path(os.environ["SHELL_QML"])
popup_state_path = Path(os.environ["POPUP_STATE_QML"])
keybinds_service_path = Path(os.environ["KEYBINDS_SERVICE_QML"])
keybinds_conf_path = Path(os.environ["KEYBINDS_CONF"])
readme_path = Path(os.environ["README_PATH"])

assert cheatsheet_path.exists(), "Cheatsheet.qml must exist"
assert keybinds_service_path.exists(), "KeybindsService.qml must exist"

cheatsheet_text = cheatsheet_path.read_text(encoding="utf-8")
shell_text = shell_path.read_text(encoding="utf-8")
popup_state_text = popup_state_path.read_text(encoding="utf-8")
keybinds_service_text = keybinds_service_path.read_text(encoding="utf-8")
keybinds_conf_text = keybinds_conf_path.read_text(encoding="utf-8")
readme_text = readme_path.read_text(encoding="utf-8")

assert re.search(r"\bScope\s*{", cheatsheet_text), "Cheatsheet must use a Scope root"
assert re.search(r"\bPanelWindow\s*{", cheatsheet_text), "Cheatsheet must define a PanelWindow"
assert re.search(r'target:\s*"toggle-cheatsheet"', cheatsheet_text), "Cheatsheet must expose toggle-cheatsheet IPC"
assert re.search(r'function\s+toggle\(\):\s*void\s*{[^}]*PopupStateService\.toggleExclusive\("cheatsheet"\)', cheatsheet_text, re.S), "Cheatsheet toggle() must use PopupStateService.toggleExclusive"
assert re.search(r'function\s+show\(\):\s*void\s*{[^}]*PopupStateService\.openExclusive\("cheatsheet"\)', cheatsheet_text, re.S), "Cheatsheet show() must use PopupStateService.openExclusive"
assert re.search(r'function\s+hide\(\):\s*void\s*{[^}]*PopupStateService\.openPopupId === "cheatsheet"[^}]*PopupStateService\.closeAll\(\)', cheatsheet_text, re.S), "Cheatsheet hide() must close via PopupStateService.closeAll()"
assert re.search(r'Connections\s*{\s*target:\s*PopupStateService', cheatsheet_text, re.S), "Cheatsheet must react to PopupStateService"
assert re.search(r'\.visible\s*=\s*\(PopupStateService\.openPopupId === "cheatsheet"\)', cheatsheet_text), 'Cheatsheet visibility must follow openPopupId === "cheatsheet"'
assert 'PopupStateService.closeAll()' in cheatsheet_text, "Cheatsheet backdrop or Escape must close all popups"
assert 'Keys.onEscapePressed' in cheatsheet_text, "Cheatsheet must close on Escape"
assert 'KeybindsService.keybinds' in cheatsheet_text, "Cheatsheet must read KeybindsService.keybinds"
assert re.search(r'function\s+groupKeybindsBySection\s*\(', cheatsheet_text), "Cheatsheet must group keybinds by section"
assert re.search(r'groupKeybindsBySection\s*\(\s*KeybindsService\.keybinds\s*\)', cheatsheet_text), "Cheatsheet must derive grouped sections from KeybindsService.keybinds"
assert re.search(r'function\s+bindingTokens\s*\(', cheatsheet_text), "Cheatsheet must split shortcuts into per-token keycaps"
assert 'section' in cheatsheet_text, "Cheatsheet must render grouped sections"
assert re.search(r'Rectangle\s*{\s*required property var modelData\s*\n\s*Layout\.fillWidth: true\s*\n\s*implicitHeight:\s*\w+\.implicitHeight\s*\+\s*\d+', cheatsheet_text, re.S), "Cheatsheet section cards must expose implicitHeight to stabilize layout sizing"
assert 'color: Qt.rgba(0, 0, 0, 0.50)' in cheatsheet_text, "Cheatsheet scrim must use the softer end-4 opacity"
assert re.search(r'id:\s*cheatsheetCard.*?border\.color:\s*GlobalState\.surface0', cheatsheet_text, re.S), "Cheatsheet card border must use a subtle surface tone"
assert re.search(r'text:\s*"Keyboard shortcuts".*?color:\s*GlobalState\.text', cheatsheet_text, re.S), "Cheatsheet title must use neutral text color"
assert re.search(r'text:\s*modelData\.section.*?font\.pixelSize:\s*20.*?font\.weight:\s*Font\.DemiBold', cheatsheet_text, re.S), "Cheatsheet section titles must use the softened end-4 sizing"
assert re.search(r'GridLayout\s*{\s*id:\s*bindingGrid.*?columns:\s*2', cheatsheet_text, re.S), "Cheatsheet rows must use a 2-column key/description grid"
assert re.search(r'model:\s*root\.bindingTokens\(modelData\)', cheatsheet_text), "Cheatsheet must render keycaps from bindingTokens()"
assert re.search(r'font\.family:\s*"monospace"', cheatsheet_text), "Cheatsheet keycaps must use monospace text"
assert re.search(r'extraBottomBorderWidth:\s*\d+', cheatsheet_text), "Cheatsheet keycaps must keep the end-4 3D lip styling"
assert 'Layout.minimumWidth: 0' in cheatsheet_text, "Cheatsheet binding description column must shrink to avoid overlap"
assert 'wrapMode: Text.WrapAnywhere' in cheatsheet_text, "Cheatsheet shortcut labels must wrap long keybinds"
assert 'Layout.maximumWidth:' in cheatsheet_text, "Cheatsheet shortcut badge width must be capped to avoid overlap"
assert re.search(r'text:\s*modelData\.description.*?font\.pixelSize:\s*12.*?renderType:\s*Text\.NativeRendering', cheatsheet_text, re.S), "Cheatsheet descriptions must use the tightened end-4 typography"
assert 'pragma Singleton' in keybinds_service_text, "KeybindsService must be present for the cheatsheet"
assert '"cheatsheet"' in popup_state_text, "PopupStateService registry comment must mention cheatsheet"
assert re.search(r'\bCheatsheet\s*{\s*}', shell_text), "shell.qml must instantiate Cheatsheet {}"

assert 'bindd = $mainMod, slash, Opens the Quickshell keybind cheatsheet, exec, qs ipc call toggle-cheatsheet toggle' in keybinds_conf_text, "Plain Mod+/ must toggle the cheatsheet"
assert 'bindd = $mainMod SHIFT, slash, Switch to the previous workspace, workspace, previous' in keybinds_conf_text, "Previous workspace bind must move to Mod+Shift+/"
assert 'bindd = $mainMod, slash, Switch to the previous workspace, workspace, previous' not in keybinds_conf_text, "Previous workspace bind must not stay on plain Mod+/"

assert '| `Cheatsheet.qml` | Fullscreen keybind cheatsheet overlay. Parses Hyprland `bindd` descriptions and toggles via `qs ipc call toggle-cheatsheet toggle`. |' in readme_text, "README must document Cheatsheet.qml and its IPC toggle"
assert '| `Mod + /` | Toggle **Keybind Cheatsheet** (Quickshell) |' in readme_text, "README must document the Mod+/ cheatsheet shortcut"
assert '| `Mod + Shift + /` | Jump to previous workspace |' in readme_text, "README must document the remapped previous-workspace shortcut"
assert 'Confirm IPC: `qs ipc call toggle-launcher toggle`, `qs ipc call toggle-cheatsheet toggle`' in readme_text, "README troubleshooting must mention cheatsheet IPC"
PY
