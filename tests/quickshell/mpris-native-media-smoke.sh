#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

media_service_qml="$repo_root/config/quickshell/services/MediaService.qml"

MEDIA_SERVICE_QML="$media_service_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

text = Path(os.environ["MEDIA_SERVICE_QML"]).read_text(encoding="utf-8")

assert re.search(r'^\s*import\s+Quickshell\.Services\.Mpris\b', text, re.M), "MediaService must import Quickshell.Services.Mpris"
assert not re.search(r'\bplayerctl\b', text), "MediaService must not shell out to playerctl"
assert re.search(r'\bmodel\s*:\s*Mpris\.players\b', text), "MediaService must track native Mpris.players"
assert re.search(r'\bproperty\s+var\s+activePlayer\b', text), "MediaService must expose activePlayer"
assert re.search(r'\bfunction\s+playPause\s*\(', text), "MediaService must expose playPause control"
assert re.search(r'\bfunction\s+next\s*\(', text), "MediaService must expose next control"
assert re.search(r'\bfunction\s+previous\s*\(', text), "MediaService must expose previous control"
assert re.search(r'\bMprisPlaybackState\.(Playing|Paused|Stopped)\b', text), "MediaService must map MprisPlaybackState to status text"
assert re.search(r'\bsignal\s+mediaStateChanged\s*\(\)', text), "MediaService must expose mediaStateChanged signal for OSD media bus consumers"
assert re.search(r'\bmediaStateChanged\s*\(\)', text), "MediaService must emit mediaStateChanged when media state updates"
PY
