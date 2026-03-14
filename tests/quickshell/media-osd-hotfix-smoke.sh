#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

media_widget_qml="$repo_root/config/quickshell/components/MediaWidget.qml"
cava_service_qml="$repo_root/config/quickshell/services/CavaService.qml"

MEDIA_WIDGET_QML="$media_widget_qml" \
CAVA_SERVICE_QML="$cava_service_qml" \
python - <<'PY'
from pathlib import Path
import os
import re

media_widget_text = Path(os.environ["MEDIA_WIDGET_QML"]).read_text(encoding="utf-8")
cava_service_text = Path(os.environ["CAVA_SERVICE_QML"]).read_text(encoding="utf-8")

assert re.search(r'\bproperty\s+int\s+maxWidgetWidth\s*:', media_widget_text), "MediaWidget must define a maxWidgetWidth cap"
assert re.search(r'\bwidth\s*:\s*Math\.min\s*\(', media_widget_text), "MediaWidget width must clamp to prevent title overlap"
assert re.search(r'\bproperty\s+int\s+visualizerBars\s*:\s*[1-6]\b', media_widget_text), "MediaWidget visualizer bar count must be reduced for bar footprint"
assert re.search(r'\bmodel\s*:\s*root\.visualizerBars\b', media_widget_text), "MediaWidget visualizer repeater must use visualizerBars"
assert re.search(r'\bproperty\s+int\s+visualizerBarWidth\s*:\s*[1-4]\b', media_widget_text), "MediaWidget visualizer bars must be narrow"
assert re.search(r'\bwidth\s*:\s*root\.visualizerBarWidth\b', media_widget_text), "MediaWidget visualizer delegate width must use visualizerBarWidth"

assert re.search(r'\bproperty\s+int\s+maxRestartAttempts\s*:\s*\d+', cava_service_text), "CavaService must define max restart attempts"
assert re.search(r'\bif\s*\(\s*root\._failCount\s*<=\s*root\.maxRestartAttempts\s*\)', cava_service_text), "CavaService restart guard must use maxRestartAttempts"
assert re.search(r'\belse\s*{[^}]*root\._bars\s*=\s*\[\][^}]*}', cava_service_text, re.S), "CavaService must reset bars when restart guard is exhausted"
assert not re.search(r'_failCount\s*<=\s*5', cava_service_text), "CavaService must not retain hardcoded restart guard literals"
PY
