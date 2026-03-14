#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

media_service_qml="$repo_root/config/quickshell/services/MediaService.qml"
osd_media_service_qml="$repo_root/config/quickshell/services/OSDMediaService.qml"
osd_event_bus_qml="$repo_root/config/quickshell/services/OSDEventBus.qml"
osd_qml="$repo_root/config/quickshell/components/OSD.qml"

MEDIA_SERVICE_QML="$media_service_qml" \
OSD_MEDIA_SERVICE_QML="$osd_media_service_qml" \
OSD_EVENT_BUS_QML="$osd_event_bus_qml" \
OSD_QML="$osd_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

text = Path(os.environ["MEDIA_SERVICE_QML"]).read_text(encoding="utf-8")
media_osd = Path(os.environ["OSD_MEDIA_SERVICE_QML"]).read_text(encoding="utf-8")
event_bus = Path(os.environ["OSD_EVENT_BUS_QML"]).read_text(encoding="utf-8")
osd = Path(os.environ["OSD_QML"]).read_text(encoding="utf-8")

assert re.search(r'^\s*import\s+Quickshell\.Services\.Mpris\b', text, re.M), "MediaService must import Quickshell.Services.Mpris"
assert not re.search(r'\bplayerctl\b', text), "MediaService must not shell out to playerctl"
assert re.search(r'\bmodel\s*:\s*Mpris\.players\b', text), "MediaService must track native Mpris.players"
assert re.search(r'\bproperty\s+var\s+activePlayer\b', text), "MediaService must expose activePlayer"
assert re.search(r'\bfunction\s+playPause\s*\(', text), "MediaService must expose playPause control"
assert re.search(r'\bfunction\s+next\s*\(', text), "MediaService must expose next control"
assert re.search(r'\bfunction\s+previous\s*\(', text), "MediaService must expose previous control"
assert re.search(r'\bMprisPlaybackState\.(Playing|Paused|Stopped)\b', text), "MediaService must map MprisPlaybackState to status text"
assert re.search(r'\bsignal\s+mediaStateChanged\s*\(', text), "MediaService must emit mediaStateChanged transitions for OSD pipeline"

assert re.search(r'^\s*pragma\s+Singleton\b', media_osd, re.M), "OSDMediaService must be a QML singleton"
assert re.search(r'^\s*import\s+"\."\s*$', media_osd, re.M), "OSDMediaService must import local services module"
assert re.search(r'\bConnections\s*{\s*target\s*:\s*MediaService', media_osd, re.S), "OSDMediaService must subscribe to MediaService transitions"
assert re.search(r'\bOSDEventBus\.publishMedia\(', media_osd), "OSDMediaService must publish normalized media OSD events"
assert re.search(r'\bproperty\s+string\s+lastSignature\b', media_osd), "OSDMediaService must dedupe repeated media events"
assert re.search(r'\bproperty\s+int\s+minimumEmitIntervalMs\s*:\s*\d+', media_osd), "OSDMediaService must include anti-spam emit interval"

assert re.search(r'^\s*pragma\s+Singleton\b', event_bus, re.M), "OSDEventBus must be a QML singleton"
assert re.search(r'\bsignal\s+eventPublished\s*\(', event_bus), "OSDEventBus must expose normalized event signal"
assert re.search(r'\bfunction\s+publishMedia\s*\(', event_bus), "OSDEventBus must provide publishMedia helper"

assert re.search(r'\bproperty\s+string\s+mediaTitle\b', osd), "OSD must track media title for rendering"
assert re.search(r'\bConnections\s*{\s*target\s*:\s*OSDEventBus', osd, re.S), "OSD must subscribe to OSDEventBus events"
assert re.search(r'\bif\s*\(\s*evt\.kind\s*===\s*"media"\s*\)', osd), "OSD must render media branch from normalized events"
PY
