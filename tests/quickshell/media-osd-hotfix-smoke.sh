#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

media_widget_qml="$repo_root/config/quickshell/components/MediaWidget.qml"
osd_qml="$repo_root/config/quickshell/components/OSD.qml"
osd_audio_service_qml="$repo_root/config/quickshell/services/OSDAudioService.qml"
osd_event_bus_qml="$repo_root/config/quickshell/services/OSDEventBus.qml"
cava_service_qml="$repo_root/config/quickshell/services/CavaService.qml"

MEDIA_WIDGET_QML="$media_widget_qml" \
OSD_QML="$osd_qml" \
OSD_AUDIO_SERVICE_QML="$osd_audio_service_qml" \
OSD_EVENT_BUS_QML="$osd_event_bus_qml" \
CAVA_SERVICE_QML="$cava_service_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

media_widget_text = Path(os.environ["MEDIA_WIDGET_QML"]).read_text(encoding="utf-8")
osd_text = Path(os.environ["OSD_QML"]).read_text(encoding="utf-8")
osd_audio_service_text = Path(os.environ["OSD_AUDIO_SERVICE_QML"]).read_text(encoding="utf-8")
osd_event_bus_text = Path(os.environ["OSD_EVENT_BUS_QML"]).read_text(encoding="utf-8")
cava_service_text = Path(os.environ["CAVA_SERVICE_QML"]).read_text(encoding="utf-8")

assert re.search(r'\bproperty\s+int\s+maxWidgetWidth\s*:', media_widget_text), "MediaWidget must define a maxWidgetWidth cap"
assert re.search(r'\bwidth\s*:\s*Math\.min\s*\(', media_widget_text), "MediaWidget width must clamp to prevent title overlap"
assert re.search(r'\bproperty\s+int\s+visualizerBars\s*:\s*[1-6]\b', media_widget_text), "MediaWidget visualizer bar count must be reduced for bar footprint"
assert re.search(r'\bmodel\s*:\s*root\.visualizerBars\b', media_widget_text), "MediaWidget visualizer repeater must use visualizerBars"
assert re.search(r'\bproperty\s+int\s+visualizerBarWidth\s*:\s*[1-4]\b', media_widget_text), "MediaWidget visualizer bars must be narrow"
assert re.search(r'\bwidth\s*:\s*root\.visualizerBarWidth\b', media_widget_text), "MediaWidget visualizer delegate width must use visualizerBarWidth"

assert not re.search(r'\bproperty\s+int\s+lastVolume\s*:\s*-1\b', osd_text), "OSD must not track audio cache state after service split"
assert not re.search(r'\bproperty\s+bool\s+lastMuted\s*:\s*false\b', osd_text), "OSD must not track audio mute cache state after service split"
assert not re.search(r'^\s*import\s+Quickshell\.Services\.Pipewire\b', osd_text, re.M), "OSD must not import Pipewire directly after service split"
assert not re.search(r'\breadonly\s+property\s+var\s+audioSink\s*:', osd_text), "OSD must not bind audio sink directly"
assert not re.search(r'\breadonly\s+property\s+bool\s+audioReady\s*:', osd_text), "OSD must not expose audio readiness logic"
assert not re.search(r'\bid\s*:\s*volumeFallbackWatcher\b', osd_text), "OSD must remove legacy volume fallback watcher"

assert re.search(r'^\s*pragma\s+Singleton\b', osd_audio_service_text, re.M), "OSDAudioService must be a singleton"
assert re.search(r'^\s*import\s+Quickshell\.Services\.Pipewire\b', osd_audio_service_text, re.M), "OSDAudioService must import Pipewire"
assert re.search(r'\breadonly\s+property\s+var\s+audioSink\s*:\s*Pipewire\.defaultAudioSink', osd_audio_service_text), "OSDAudioService must bind default sink"
assert re.search(r'\breadonly\s+property\s+bool\s+audioReady\s*:\s*!!\(root\.audioSink\s*&&\s*root\.audioSink\.audio\)', osd_audio_service_text), "OSDAudioService must gate on sink readiness"
assert re.search(r'\btarget\s*:\s*root\.audioSink\?\.audio\s*\?\?\s*null\b', osd_audio_service_text), "OSDAudioService must subscribe to sink audio signals"
assert re.search(r'\bfunction\s+onVolumeChanged\s*\(', osd_audio_service_text), "OSDAudioService must handle volume changes"
assert re.search(r'\bfunction\s+onMutedChanged\s*\(', osd_audio_service_text), "OSDAudioService must handle mute changes"
assert re.search(r'\bif\s*\(\s*!isNaN\(vol\)\s*&&\s*vol\s*!==\s*root\._lastVolume\s*\)', osd_audio_service_text), "OSDAudioService must dedupe unchanged volume"
assert re.search(r'\bif\s*\(\s*isMuted\s*!==\s*root\._lastMuted\s*\)', osd_audio_service_text), "OSDAudioService must dedupe unchanged mute state"
assert not re.search(r'\brepeat\s*:\s*true\b', osd_audio_service_text), "OSDAudioService must not include polling fallback timers"
assert not re.search(r'\bpactl\b', osd_audio_service_text), "OSDAudioService must not shell out to pactl"
assert not re.search(r'\bpamixer\b', osd_audio_service_text), "OSDAudioService must not shell out to pamixer"

assert re.search(r'^\s*pragma\s+Singleton\b', osd_event_bus_text, re.M), "OSDEventBus must be a singleton"
assert re.search(r'\bsignal\s+showRequested\s*\(', osd_event_bus_text), "OSDEventBus must expose showRequested signal"
assert re.search(r'\bfunction\s+publishAudio\s*\(', osd_event_bus_text), "OSDEventBus must expose publishAudio"
assert re.search(r'parseInt\(parts\[0\],\s*10\)', osd_text), "OSD brightness parser must parse current value with base-10 radix"
assert re.search(r'parseInt\(parts\[1\],\s*10\)', osd_text), "OSD brightness parser must parse max value with base-10 radix"
assert not re.search(r'\bpactl\b', osd_text), "OSD must not shell out to pactl subscribe for volume events"
assert not re.search(r'\bpamixer\b', osd_text), "OSD must not shell out to pamixer for volume events"

assert re.search(r'\bproperty\s+int\s+maxRestartAttempts\s*:\s*\d+', cava_service_text), "CavaService must define max restart attempts"
assert re.search(r'\bif\s*\(\s*root\._failCount\s*<=\s*root\.maxRestartAttempts\s*\)', cava_service_text), "CavaService restart guard must use maxRestartAttempts"
assert re.search(r'\belse\s*{[^}]*root\._bars\s*=\s*\[\][^}]*}', cava_service_text, re.S), "CavaService must reset bars when restart guard is exhausted"
assert not re.search(r'_failCount\s*<=\s*5', cava_service_text), "CavaService must not retain hardcoded restart guard literals"
PY
