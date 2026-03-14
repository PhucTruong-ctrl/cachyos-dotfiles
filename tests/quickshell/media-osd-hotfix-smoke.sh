#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

media_widget_qml="$repo_root/config/quickshell/components/MediaWidget.qml"
osd_qml="$repo_root/config/quickshell/components/OSD.qml"
cava_service_qml="$repo_root/config/quickshell/services/CavaService.qml"
appearance_qml="$repo_root/config/quickshell/services/Appearance.qml"
global_state_qml="$repo_root/config/quickshell/services/GlobalState.qml"

MEDIA_WIDGET_QML="$media_widget_qml" \
OSD_QML="$osd_qml" \
CAVA_SERVICE_QML="$cava_service_qml" \
APPEARANCE_QML="$appearance_qml" \
GLOBAL_STATE_QML="$global_state_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

media_widget_text = Path(os.environ["MEDIA_WIDGET_QML"]).read_text(encoding="utf-8")
osd_text = Path(os.environ["OSD_QML"]).read_text(encoding="utf-8")
cava_service_text = Path(os.environ["CAVA_SERVICE_QML"]).read_text(encoding="utf-8")
appearance_text = Path(os.environ["APPEARANCE_QML"]).read_text(encoding="utf-8")
global_state_text = Path(os.environ["GLOBAL_STATE_QML"]).read_text(encoding="utf-8")

assert re.search(r'\bproperty\s+int\s+maxWidgetWidth\s*:', media_widget_text), "MediaWidget must define a maxWidgetWidth cap"
assert re.search(r'\bwidth\s*:\s*Math\.min\s*\(', media_widget_text), "MediaWidget width must clamp to prevent title overlap"
assert re.search(r'\bproperty\s+int\s+visualizerBars\s*:\s*[1-6]\b', media_widget_text), "MediaWidget visualizer bar count must be reduced for bar footprint"
assert re.search(r'\bmodel\s*:\s*root\.visualizerBars\b', media_widget_text), "MediaWidget visualizer repeater must use visualizerBars"
assert re.search(r'\bproperty\s+int\s+visualizerBarWidth\s*:\s*[1-4]\b', media_widget_text), "MediaWidget visualizer bars must be narrow"
assert re.search(r'\bwidth\s*:\s*root\.visualizerBarWidth\b', media_widget_text), "MediaWidget visualizer delegate width must use visualizerBarWidth"

assert re.search(r'\bproperty\s+bool\s+active\s*:\s*false\b', osd_text), "OSD must expose local visibility state"
assert re.search(r'\bvisible\s*:\s*active\b', osd_text), "OSD visibility must be presentation-only"
assert re.search(r'\bproperty\s+var\s+eventSource\s*:\s*GlobalState\b', osd_text), "OSD must consume shared service events"
assert re.search(r'\bConnections\s*{[\s\S]*?target\s*:\s*root\.eventSource', osd_text), "OSD must subscribe to service event source"
assert re.search(r'\bfunction\s+onOsdEventChanged\s*\(', osd_text), "OSD must react to service event updates"
assert re.search(r'\bif\s*\(\s*!root\.eventSource\s*\)\s*return;', osd_text), "OSD consumer must guard missing event source"
assert re.search(r'\bfunction\s+normalizeEvent\s*\(', osd_text), "OSD must normalize incoming payload shape"
assert re.search(r'\bfunction\s+showFromEvent\s*\(', osd_text), "OSD must funnel all payload kinds through shared show behavior"
assert re.search(r'\broot\.showFromEvent\(event\)', osd_text), "OSD must render from normalized event payload"
assert re.search(r'\bMath\.max\(0,\s*Math\.min\(100,\s*event\.value\)\)', osd_text), "OSD must clamp event value range"
assert re.search(r'\binterval\s*:\s*Appearance\.osdHideDelay\b', osd_text), "OSD hide timer must use Appearance constant"
assert re.search(r'\bimplicitWidth\s*:\s*Appearance\.osdWidth\b', osd_text), "OSD width must use Appearance constant"
assert re.search(r'\bimplicitHeight\s*:\s*Appearance\.osdHeight\b', osd_text), "OSD height must use Appearance constant"
assert re.search(r'\bbottom\s*:\s*Appearance\.osdBottomMargin\b', osd_text), "OSD bottom margin must use Appearance constant"
assert re.search(r'\banchors\.margins\s*:\s*Appearance\.osdContentMargin\b', osd_text), "OSD content margins must use Appearance constant"
assert re.search(r'\bspacing\s*:\s*Appearance\.osdContentSpacing\b', osd_text), "OSD spacing must use Appearance constant"
assert re.search(r'\bfont\.pixelSize\s*:\s*Appearance\.osdIconSize\b', osd_text), "OSD icon size must use Appearance constant"
assert re.search(r'\bLayout\.preferredHeight\s*:\s*Appearance\.osdBarHeight\b', osd_text), "OSD bar height must use Appearance constant"
assert re.search(r'\bradius\s*:\s*Appearance\.osdBarRadius\b', osd_text), "OSD bar radius must use Appearance constant"
assert re.search(r'\bfont\.pixelSize\s*:\s*Appearance\.osdValueSize\b', osd_text), "OSD value text size must use Appearance constant"
assert re.search(r'\bcolor\s*:\s*GlobalState\.osdBackground\b', osd_text), "OSD background color must come from GlobalState"
assert re.search(r'\bcolor\s*:\s*GlobalState\.osdTrack\b', osd_text), "OSD track color must come from GlobalState"
assert re.search(r'\bcolor\s*:\s*GlobalState\.osdFill\b', osd_text), "OSD fill color must come from GlobalState"
assert re.search(r'\bcolor\s*:\s*GlobalState\.osdText\b', osd_text), "OSD text color must come from GlobalState"
assert re.search(r'\bcolor\s*:\s*GlobalState\.osdIcon\b', osd_text), "OSD icon color must come from GlobalState"
assert re.search(r'\breadonly\s+property\s+real\s+osdBackgroundBoost\s*:\s*0\.05\b', appearance_text), "Appearance must expose OSD background boost constant"
assert re.search(r'\bosdBackground\s*:\s*Qt\.rgba\(surface0\.r,\s*surface0\.g,\s*surface0\.b,\s*Appearance\.panelOpacity\s*\+\s*Appearance\.osdBackgroundBoost\)', global_state_text), "GlobalState must avoid magic OSD alpha values"
assert not re.search(r'\bAppearance\.panelOpacity\s*\+\s*0\.05\b', global_state_text), "GlobalState must not use magic OSD alpha increments"
assert not re.search(r'^\s*import\s+Quickshell\.Services\.Pipewire\b', osd_text, re.M), "OSD must not directly import Pipewire"
assert not re.search(r'\breadonly\s+property\s+var\s+audioSink\b', osd_text), "OSD must not bind audio sink directly"
assert not re.search(r'\breadonly\s+property\s+bool\s+audioReady\b', osd_text), "OSD must not own audio readiness logic"
assert not re.search(r'\bvolumeFallbackWatcher\b', osd_text), "OSD must not define legacy fallback watcher"
assert not re.search(r'\bbrightnessWatcher\b', osd_text), "OSD must not define brightness watcher process"
assert not re.search(r'\bProcess\s*{', osd_text), "OSD must not launch processes"
assert not re.search(r'\bparseInt\(', osd_text), "OSD must not parse brightness values directly"
assert not re.search(r'\bpactl\b', osd_text), "OSD must not shell out to pactl subscribe for events"
assert not re.search(r'\bpamixer\b', osd_text), "OSD must not shell out to pamixer for events"

assert re.search(r'\bproperty\s+int\s+maxRestartAttempts\s*:\s*\d+', cava_service_text), "CavaService must define max restart attempts"
assert re.search(r'\bif\s*\(\s*root\._failCount\s*<=\s*root\.maxRestartAttempts\s*\)', cava_service_text), "CavaService restart guard must use maxRestartAttempts"
assert re.search(r'\belse\s*{[^}]*root\._bars\s*=\s*\[\][^}]*}', cava_service_text, re.S), "CavaService must reset bars when restart guard is exhausted"
assert not re.search(r'_failCount\s*<=\s*5', cava_service_text), "CavaService must not retain hardcoded restart guard literals"
PY
