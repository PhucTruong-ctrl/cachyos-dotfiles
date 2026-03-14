#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

media_widget_qml="$repo_root/config/quickshell/components/MediaWidget.qml"
osd_qml="$repo_root/config/quickshell/components/OSD.qml"
cava_service_qml="$repo_root/config/quickshell/services/CavaService.qml"
osd_event_bus_qml="$repo_root/config/quickshell/services/OSDEventBus.qml"
osd_brightness_service_qml="$repo_root/config/quickshell/services/OSDBrightnessService.qml"

MEDIA_WIDGET_QML="$media_widget_qml" \
OSD_QML="$osd_qml" \
CAVA_SERVICE_QML="$cava_service_qml" \
OSD_EVENT_BUS_QML="$osd_event_bus_qml" \
OSD_BRIGHTNESS_SERVICE_QML="$osd_brightness_service_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

media_widget_text = Path(os.environ["MEDIA_WIDGET_QML"]).read_text(encoding="utf-8")
osd_text = Path(os.environ["OSD_QML"]).read_text(encoding="utf-8")
cava_service_text = Path(os.environ["CAVA_SERVICE_QML"]).read_text(encoding="utf-8")
osd_event_bus_text = Path(os.environ["OSD_EVENT_BUS_QML"]).read_text(encoding="utf-8")
osd_brightness_service_text = Path(os.environ["OSD_BRIGHTNESS_SERVICE_QML"]).read_text(encoding="utf-8")

assert re.search(r'\bproperty\s+int\s+maxWidgetWidth\s*:', media_widget_text), "MediaWidget must define a maxWidgetWidth cap"
assert re.search(r'\bwidth\s*:\s*Math\.min\s*\(', media_widget_text), "MediaWidget width must clamp to prevent title overlap"
assert re.search(r'\bproperty\s+int\s+visualizerBars\s*:\s*[1-6]\b', media_widget_text), "MediaWidget visualizer bar count must be reduced for bar footprint"
assert re.search(r'\bmodel\s*:\s*root\.visualizerBars\b', media_widget_text), "MediaWidget visualizer repeater must use visualizerBars"
assert re.search(r'\bproperty\s+int\s+visualizerBarWidth\s*:\s*[1-4]\b', media_widget_text), "MediaWidget visualizer bars must be narrow"
assert re.search(r'\bwidth\s*:\s*root\.visualizerBarWidth\b', media_widget_text), "MediaWidget visualizer delegate width must use visualizerBarWidth"

assert re.search(r'\bproperty\s+int\s+lastVolume\s*:\s*-1\b', osd_text), "OSD must track last volume"
assert re.search(r'\bproperty\s+bool\s+lastMuted\s*:\s*false\b', osd_text), "OSD must track mute state"
assert re.search(r'^\s*import\s+Quickshell\.Services\.Pipewire\b', osd_text, re.M), "OSD must import reactive Pipewire service"
assert re.search(r'\breadonly\s+property\s+var\s+audioSink\s*:\s*Pipewire\.defaultAudioSink', osd_text), "OSD must bind to default Pipewire audio sink"
assert re.search(r'\breadonly\s+property\s+bool\s+audioReady\s*:\s*!!\(root\.audioSink\s*&&\s*root\.audioSink\.audio\)', osd_text), "OSD must expose an audioReady guard for sink rebind races"
assert re.search(r'\btarget\s*:\s*root\.audioSink\?\.audio\s*\?\?\s*null\b', osd_text), "OSD must react to Pipewire sink audio changes"
assert re.search(r'\bfunction\s+onVolumeChanged\s*\(', osd_text), "OSD must handle reactive volume changes"
assert re.search(r'\bfunction\s+onMutedChanged\s*\(', osd_text), "OSD must handle reactive mute changes"
assert re.search(r'function\s+onVolumeChanged\s*\(\)\s*{\s*if\s*\(\s*!root\.audioReady\s*\)\s*return;', osd_text), "OSD volume handler must guard until audio is ready"
assert re.search(r'function\s+onMutedChanged\s*\(\)\s*{\s*if\s*\(\s*!root\.audioReady\s*\)\s*return;', osd_text), "OSD mute handler must guard until audio is ready"
assert re.search(r'\bid\s*:\s*volumeFallbackWatcher\b', osd_text), "OSD must define a volume fallback watcher"
assert re.search(r'\binterval\s*:\s*\d+\b', osd_text), "OSD fallback watcher must have a polling interval"
assert re.search(r'\brepeat\s*:\s*true\b', osd_text), "OSD fallback watcher must run continuously"
assert re.search(r'\bonTriggered\s*:\s*{[\s\S]*?root\.sinkVolumePercent\(\)', osd_text), "OSD fallback watcher must read current sink volume"
assert re.search(r'\bonTriggered\s*:\s*{[\s\S]*?root\.show\("volume"', osd_text), "OSD fallback watcher must surface missed volume/mute updates"
assert re.search(r'\bonTriggered\s*:\s*{\s*if\s*\(\s*!root\.audioReady\s*\)\s*return;', osd_text), "OSD fallback watcher must no-op until audio is ready"
assert re.search(r'function\s+onVolumeChanged\s*\(\)\s*{(?:(?!function\s+onMutedChanged)[\s\S])*const\s+isMuted\s*=\s*root\.audioSink\s*&&\s*root\.audioSink\.audio\s*\?\s*root\.audioSink\.audio\.muted\s*:\s*false', osd_text), "OSD volume updates must read current sink mute state to avoid rebind races"
assert re.search(r'\bif\s*\(\s*!isNaN\(vol\)\s*&&\s*vol\s*!==\s*root\.lastVolume\s*\)', osd_text), "OSD must only show volume when value changes"
assert re.search(r'\bif\s*\(\s*isMuted\s*!==\s*root\.lastMuted\s*\)', osd_text), "OSD must only show mute icon when mute state changes"
assert re.search(r'\bMath\.round\(root\.audioSink\.audio\.volume\s*\*\s*100\)', osd_text), "OSD must derive volume percent reactively from Pipewire sink"
assert not re.search(r'\bid\s*:\s*brightnessWatcher\b', osd_text), "OSD must not keep legacy brightness watcher in presentation layer"
assert re.search(r'\btarget\s*:\s*OSDEventBus\b', osd_text), "OSD must consume normalized events via OSDEventBus"
assert re.search(r'\bonEventPublished\s*\(', osd_text), "OSD must react to published event bus updates"

assert re.search(r'^\s*pragma\s+Singleton\b', osd_event_bus_text, re.M), "OSDEventBus must be a singleton"
assert re.search(r'\bsignal\s+eventPublished\s*\(', osd_event_bus_text), "OSDEventBus must expose eventPublished signal"
assert re.search(r'\bfunction\s+publishBrightness\s*\(', osd_event_bus_text), "OSDEventBus must provide brightness publish helper"

assert re.search(r'^\s*pragma\s+Singleton\b', osd_brightness_service_text, re.M), "OSDBrightnessService must be a singleton"
assert re.search(r'\bproperty\s+int\s+ddcDebounceMs\s*:\s*300\b', osd_brightness_service_text), "OSDBrightnessService must debounce DDC brightness updates"
assert re.search(r'\binterval\s*:\s*root\.pendingIsDdc\s*\?\s*root\.ddcDebounceMs\s*:\s*0\b', osd_brightness_service_text), "OSDBrightnessService must delay DDC but keep backlight immediate"
assert re.search(r'parseInt\(parts\[2\],\s*10\)', osd_brightness_service_text), "OSDBrightnessService must parse current brightness with base-10 radix"
assert re.search(r'parseInt\(parts\[3\],\s*10\)', osd_brightness_service_text), "OSDBrightnessService must parse max brightness with base-10 radix"
assert re.search(r'\bif\s*\(\s*parts\.length\s*<\s*4\s*\)\s*return;', osd_brightness_service_text), "OSDBrightnessService must guard malformed brightnessctl lines"
assert re.search(r'\bif\s*\(\s*isNaN\(cur\)\s*\|\|\s*isNaN\(max\)\s*\|\|\s*max\s*<=\s*0\s*\)\s*return;', osd_brightness_service_text), "OSDBrightnessService must guard invalid numeric brightness readings"
assert re.search(r'\bif\s*\(\s*deviceKey\s*!==\s*root\.lastDeviceKey\s*\)', osd_brightness_service_text), "OSDBrightnessService must reset dedupe state on device transitions"
assert re.search(r'\bOSDEventBus\.publishBrightness\s*\(', osd_brightness_service_text), "OSDBrightnessService must publish normalized brightness events"
assert not re.search(r'\bpactl\b', osd_text), "OSD must not shell out to pactl subscribe for volume events"
assert not re.search(r'\bpamixer\b', osd_text), "OSD must not shell out to pamixer for volume events"

assert re.search(r'\bproperty\s+int\s+maxRestartAttempts\s*:\s*\d+', cava_service_text), "CavaService must define max restart attempts"
assert re.search(r'\bif\s*\(\s*root\._failCount\s*<=\s*root\.maxRestartAttempts\s*\)', cava_service_text), "CavaService restart guard must use maxRestartAttempts"
assert re.search(r'\belse\s*{[^}]*root\._bars\s*=\s*\[\][^}]*}', cava_service_text, re.S), "CavaService must reset bars when restart guard is exhausted"
assert not re.search(r'_failCount\s*<=\s*5', cava_service_text), "CavaService must not retain hardcoded restart guard literals"
PY
