// OSD.qml — Volume/brightness on-screen display spawned by hardware key events.
// Uses hardware listeners + timers to show transient overlays near the bar.
// Colors + blur align with GlobalState and Appearance.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-osd"
    exclusionMode: ExclusionMode.Ignore

    // Center-bottom positioning
    implicitWidth: 320
    implicitHeight: 64

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        bottom: 80
        left: Math.round((Screen.width - 320) / 2)
        right: Math.round((Screen.width - 320) / 2)
    }

    color: "transparent"

    property string icon: "󰕾"
    property int value: 0
    property string type: "volume" // "volume" or "brightness"
    property int lastVolume: -1
    property bool lastMuted: false

    // ── OSD Visibility Controller ───────────────────────────────────────────
    property bool active: false
    visible: active

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.active = false
    }

    function show(newType, newValue, newIcon) {
        root.type = newType
        root.value = newValue
        root.icon = newIcon
        root.active = true
        hideTimer.restart()
    }

    // ── Data Fetching ───────────────────────────────────────────────────────

    // Volume Detection (Event-driven via pactl subscribe)
    Process {
        id: volumeEventSource
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Event 'change' on sink")) {
                    volumeFetcher.running = false
                    volumeFetcher.running = true
                    muteFetcher.running = false
                    muteFetcher.running = true
                }
            }
        }
    }

    Process {
        id: volumeFetcher
        command: ["pamixer", "--get-volume"]
        stdout: SplitParser {
            onRead: data => {
                const vol = parseInt(data.trim(), 10)
                if (!isNaN(vol) && vol !== root.lastVolume) {
                    root.lastVolume = vol
                    root.show("volume", vol, "󰕾")
                }
            }
        }
    }

    // Mute detection
    Process {
        id: muteFetcher
        command: ["pamixer", "--get-mute"]
        stdout: SplitParser {
            onRead: data => {
                const isMuted = data.trim() === "true"
                if (isMuted !== root.lastMuted) {
                    root.lastMuted = isMuted
                    root.show("volume", root.lastVolume >= 0 ? root.lastVolume : root.value, isMuted ? "󰖁" : "󰕾")
                }
            }
        }
    }

    // Brightness Detection — event-driven watcher (no inotifywait; uses a
    // long-running bash loop that reads the sysfs brightness file and only
    // emits a line when the value changes).  This replaces the previous
    // 500 ms polling timer + two forked brightnessctl processes that ran
    // unconditionally 24/7 even while the OSD was hidden.
    //
    // Output format: "<current_raw> <max_raw>" on each brightness change.
    property int lastBrightness: -1

    Process {
        id: brightnessWatcher
        command: [
            "bash", "-c",
            "BDEV=/sys/class/backlight/$(ls /sys/class/backlight | head -n1);" +
            "MAX=$(cat \"$BDEV/max_brightness\");" +
            "PREV=-1;" +
            "while true; do" +
            "  CUR=$(cat \"$BDEV/brightness\");" +
            "  if [ \"$CUR\" != \"$PREV\" ]; then" +
            "    echo \"$CUR $MAX\";" +
            "    PREV=$CUR;" +
            "  fi;" +
            "  sleep 0.25;" +
            "done"
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length === 2) {
                    const cur = parseInt(parts[0], 10)
                    const max = parseInt(parts[1], 10)
                    if (!isNaN(cur) && !isNaN(max) && max > 0) {
                        const pct = Math.round((cur / max) * 100)
                        if (pct !== root.lastBrightness && root.lastBrightness !== -1) {
                            root.show("brightness", pct, "󰃠")
                        }
                        root.lastBrightness = pct
                    }
                }
            }
        }
    }

    // ── UI Layout ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.panelRadius + 4   // OSD uses slightly larger radius (16 vs 12)
        color: Qt.rgba(
            GlobalState.surface0.r,
            GlobalState.surface0.g,
            GlobalState.surface0.b,
            Appearance.panelOpacity + 0.05   // 0.90 — slightly more opaque for readability
        )

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: root.icon
                font.pixelSize: 24
                font.family: "monospace"
                color: GlobalState.matugenPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                color: GlobalState.surface1
                radius: 4
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: (root.value / 100) * parent.width
                    height: parent.height
                    color: GlobalState.matugenPrimary
                    radius: 4
                }
            }

            Text {
                text: root.value + "%"
                font.pixelSize: 14
                font.bold: true
                color: GlobalState.text
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
