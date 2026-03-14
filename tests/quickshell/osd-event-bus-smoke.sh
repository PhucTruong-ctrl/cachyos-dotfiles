#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

event_bus_qml="$repo_root/config/quickshell/services/OSDEventBus.qml"
audio_service_qml="$repo_root/config/quickshell/services/OSDAudioService.qml"
brightness_service_qml="$repo_root/config/quickshell/services/OSDBrightnessService.qml"
media_service_qml="$repo_root/config/quickshell/services/OSDMediaService.qml"
qmldir_file="$repo_root/config/quickshell/services/qmldir"
osd_qml="$repo_root/config/quickshell/components/OSD.qml"
core_media_service_qml="$repo_root/config/quickshell/services/MediaService.qml"
global_state_qml="$repo_root/config/quickshell/services/GlobalState.qml"

OSD_EVENT_BUS_QML="$event_bus_qml" \
OSD_AUDIO_SERVICE_QML="$audio_service_qml" \
OSD_BRIGHTNESS_SERVICE_QML="$brightness_service_qml" \
OSD_MEDIA_SERVICE_QML="$media_service_qml" \
SERVICES_QMLDIR="$qmldir_file" \
OSD_QML="$osd_qml" \
MEDIA_SERVICE_QML="$core_media_service_qml" \
GLOBAL_STATE_QML="$global_state_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

event_bus_text = Path(os.environ["OSD_EVENT_BUS_QML"]).read_text(encoding="utf-8")
audio_service_text = Path(os.environ["OSD_AUDIO_SERVICE_QML"]).read_text(encoding="utf-8")
brightness_service_text = Path(os.environ["OSD_BRIGHTNESS_SERVICE_QML"]).read_text(encoding="utf-8")
media_service_text = Path(os.environ["OSD_MEDIA_SERVICE_QML"]).read_text(encoding="utf-8")
qmldir_text = Path(os.environ["SERVICES_QMLDIR"]).read_text(encoding="utf-8")
osd_text = Path(os.environ["OSD_QML"]).read_text(encoding="utf-8")
core_media_service_text = Path(os.environ["MEDIA_SERVICE_QML"]).read_text(encoding="utf-8")
global_state_text = Path(os.environ["GLOBAL_STATE_QML"]).read_text(encoding="utf-8")

for name, text in [
    ("OSDEventBus", event_bus_text),
    ("OSDAudioService", audio_service_text),
    ("OSDBrightnessService", brightness_service_text),
    ("OSDMediaService", media_service_text),
]:
    assert re.search(r"^\s*pragma\s+Singleton\b", text, re.M), f"{name} must declare pragma Singleton"

assert re.search(r"\bsignal\s+eventPublished\s*\(\s*var\s+event\s*\)", event_bus_text), "OSDEventBus must expose published event signal"
assert re.search(r"\bfunction\s+publish\s*\(\s*kind\s*,\s*value\s*,\s*icon\s*,\s*label\s*,\s*metadata\s*\)", event_bus_text), "OSDEventBus must expose normalized publish API"
assert re.search(r"\bfunction\s+publishAudio\s*\(\s*value\s*,\s*icon\s*,\s*label\s*,\s*metadata\s*\)", event_bus_text), "OSDEventBus must expose audio publish helper"
assert re.search(r"\bfunction\s+publishBrightness\s*\(\s*value\s*,\s*icon\s*,\s*metadata\s*\)", event_bus_text), "OSDEventBus must expose brightness publish helper"
assert re.search(r"\bkind\s*:\s*kind\b", event_bus_text), "OSDEventBus publish payload must include kind"
assert re.search(r"\bvalue\s*:\s*value\b", event_bus_text), "OSDEventBus publish payload must include value"
assert re.search(r"\bicon\s*:\s*icon\b", event_bus_text), "OSDEventBus publish payload must include icon"
assert re.search(r"\blabel\s*:\s*label\b", event_bus_text), "OSDEventBus publish payload must include label"
assert re.search(r"\btimestamp\s*:\s*Date\.now\(\)", event_bus_text), "OSDEventBus publish payload must include timestamp"
assert re.search(r"\bmetadata\s*:\s*metadata\s*\|\|\s*\(\{\}\)", event_bus_text), "OSDEventBus publish payload must include metadata"

assert re.search(r"\bfunction\s+publishCurrentState\s*\(", audio_service_text), "OSDAudioService must provide audio state publisher"
assert re.search(r"\breadonly\s+property\s+var\s+audioSink\s*:\s*Pipewire\.defaultAudioSink", audio_service_text), "OSDAudioService must bind Pipewire default sink"
assert re.search(r"\breadonly\s+property\s+bool\s+audioReady\s*:\s*!!\(root\.audioSink\s*&&\s*root\.audioSink\.audio\)", audio_service_text), "OSDAudioService must gate on audio readiness"
assert re.search(r"\btarget\s*:\s*root\.audioSink\?\.audio\s*\?\?\s*null\b", audio_service_text), "OSDAudioService must react to sink audio signals"
assert re.search(r"\bonVolumeChanged\s*\(\)", audio_service_text), "OSDAudioService must handle volume signals"
assert re.search(r"\bonMutedChanged\s*\(\)", audio_service_text), "OSDAudioService must handle mute signals"
assert re.search(r"\bOSDEventBus\.publishAudio\(", audio_service_text), "OSDAudioService must emit via OSDEventBus"
assert not re.search(r"\bvolumeFallbackWatcher\b", audio_service_text), "OSDAudioService must not define legacy fallback watcher"

assert re.search(r"\bcommand\s*:\s*\[\s*\"bash\"\s*,\s*\"-lc\"\s*,\s*\"brightnessctl -m --watch\"\s*\]", brightness_service_text), "OSDBrightnessService must stream brightnessctl watch output"
assert re.search(r"\bconst\s+parts\s*=\s*line\.split\(\",\"\)", brightness_service_text), "OSDBrightnessService must parse brightness stream records"
assert re.search(r"\bparseInt\(parts\[2\],\s*10\)", brightness_service_text), "OSDBrightnessService must parse brightness current value"
assert re.search(r"\bparseInt\(parts\[3\],\s*10\)", brightness_service_text), "OSDBrightnessService must parse brightness max value"
assert re.search(r"\bOSDEventBus\.publishBrightness\(", brightness_service_text), "OSDBrightnessService must emit brightness updates via bus"
assert not re.search(r"\bid\s*:\s*brightnessWatcher\b", osd_text), "OSD component must not keep legacy brightness watcher"

assert re.search(r"\bfunction\s+emitMediaEvent\s*\(", media_service_text), "OSDMediaService must provide media emission flow"
assert re.search(r"\btarget\s*:\s*MediaService\b", media_service_text), "OSDMediaService must subscribe to MediaService"
assert re.search(r"\bonMediaStateChanged\s*\(\)", media_service_text), "OSDMediaService must react to MediaService state changes"
assert re.search(r"\bOSDEventBus\.publishMedia\(", media_service_text), "OSDMediaService must emit media events to bus"

assert re.search(r"^singleton\s+OSDEventBus\s+1\.0\s+OSDEventBus\.qml\s*$", qmldir_text, re.M), "qmldir must export OSDEventBus singleton"
assert re.search(r"^singleton\s+OSDAudioService\s+1\.0\s+OSDAudioService\.qml\s*$", qmldir_text, re.M), "qmldir must export OSDAudioService singleton"
assert re.search(r"^singleton\s+OSDBrightnessService\s+1\.0\s+OSDBrightnessService\.qml\s*$", qmldir_text, re.M), "qmldir must export OSDBrightnessService singleton"
assert re.search(r"^singleton\s+OSDMediaService\s+1\.0\s+OSDMediaService\.qml\s*$", qmldir_text, re.M), "qmldir must export OSDMediaService singleton"

assert re.search(r"\bproperty\s+var\s+eventSource\s*:\s*GlobalState\b", osd_text), "OSD must consume event stream via service state"
assert re.search(r"\bfunction\s+normalizeEvent\s*\(", osd_text), "OSD must normalize bus payloads"
assert re.search(r"\bevent\.kind\b", osd_text), "OSD event normalization must support kind payload"
assert re.search(r"\bfunction\s+showFromEvent\s*\(", osd_text), "OSD must route display through normalized event handler"
assert re.search(r"\bproperty\s+bool\s+isMedia\s*:\s*root\.type\s*===\s*\"media\"", osd_text), "OSD must identify media events for final presentation polish"
assert re.search(r"\bproperty\s+string\s+displayText\s*:\s*root\.isMedia\s*&&\s*root\.label\.length\s*>\s*0\s*\?\s*root\.label\s*:\s*root\.value\s*\+\s*\"%\"", osd_text), "OSD must render media label text instead of numeric percent"
assert re.search(r"\belide\s*:\s*Text\.ElideRight", osd_text), "OSD media label text must elide to avoid overflow"
assert not re.search(r"\bvolumeFallbackWatcher\b", osd_text), "OSD component must not keep legacy volume fallback watcher"
assert not re.search(r"\bbrightnessWatcher\b", osd_text), "OSD component must not keep legacy brightness watcher"

assert re.search(r"\bsignal\s+mediaStateChanged\s*\(\)", core_media_service_text), "MediaService must expose mediaStateChanged signal for event-bus media flow"
assert re.search(r"\bmediaStateChanged\s*\(\)", core_media_service_text), "MediaService must emit mediaStateChanged updates"
assert not re.search(r"\bplayerctl\b", core_media_service_text), "MediaService path must remain native MPRIS without playerctl polling"

assert re.search(r"\btarget\s*:\s*OSDEventBus\b", global_state_text), "GlobalState must subscribe to OSDEventBus runtime events"
assert re.search(r"\bfunction\s+onEventPublished\s*\(\s*event\s*\)", global_state_text), "GlobalState must handle OSDEventBus eventPublished signal"
assert re.search(r"\bosdEvent\s*=\s*event\b", global_state_text), "GlobalState must forward bus events into osdEvent state"
PY
