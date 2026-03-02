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
                if (data.includes("sink")) {
                    volumeFetcher.running = false
                    volumeFetcher.running = true
                }
            }
        }
    }

    Process {
        id: volumeFetcher
        command: ["pamixer", "--get-volume"]
        stdout: SplitParser {
            onRead: data => {
                const vol = parseInt(data.trim())
                if (!isNaN(vol)) {
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
                root.show("volume", root.value, isMuted ? "󰖁" : "󰕾")
            }
        }
    }

    // Brightness Detection (Polling — no inotifywait available)
    property int lastBrightness: -1

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            brightnessFetcher.running = false
            brightnessFetcher.running = true
        }
    }

    Process {
        id: brightnessFetcher
        command: ["brightnessctl", "g"]
        stdout: SplitParser {
            onRead: data => {
                const val = parseInt(data.trim())
                if (!isNaN(val)) {
                    brightnessMaxFetcher.targetVal = val
                    brightnessMaxFetcher.running = false
                    brightnessMaxFetcher.running = true
                }
            }
        }
    }

    Process {
        id: brightnessMaxFetcher
        property int targetVal: 0
        command: ["brightnessctl", "m"]
        stdout: SplitParser {
            onRead: data => {
                const max = parseInt(data.trim())
                if (max > 0) {
                    const pct = Math.round((brightnessMaxFetcher.targetVal / max) * 100)
                    if (pct !== root.lastBrightness && root.lastBrightness !== -1) {
                        root.show("brightness", pct, "󰃠")
                    }
                    root.lastBrightness = pct
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
