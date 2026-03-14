// OSD.qml — Volume/brightness on-screen display spawned by hardware key events.
// Uses hardware listeners + timers to show transient overlays near the bar.
// Colors + blur align with GlobalState and Appearance.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
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
    property string mediaTitle: ""
    property string mediaSource: ""
    property int lastVolume: -1
    property bool lastMuted: false
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool audioReady: !!(root.audioSink && root.audioSink.audio)

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

    readonly property var _mediaPipelineBootstrap: OSDMediaService

    Connections {
        target: OSDEventBus

        function onEventPublished(evt) {
            if (!evt)
                return;
            if (evt.kind === "media") {
                root.mediaTitle = evt.label || ""
                root.mediaSource = evt.metadata && evt.metadata.source ? evt.metadata.source : ""
                root.show("media", typeof evt.value === "number" ? evt.value : 0, evt.icon || "󰎇")
            }
        }
    }

    // ── Data Fetching ───────────────────────────────────────────────────────

    function sinkVolumePercent(): int {
        if (!root.audioSink || !root.audioSink.audio)
            return root.lastVolume >= 0 ? root.lastVolume : root.value;
        const vol = Math.round(root.audioSink.audio.volume * 100)
        return isNaN(vol) ? (root.lastVolume >= 0 ? root.lastVolume : root.value) : vol
    }

    function syncSinkState(): void {
        if (!root.audioSink || !root.audioSink.audio)
            return;
        root.lastVolume = root.sinkVolumePercent()
        root.lastMuted = root.audioSink.audio.muted
    }

    Connections {
        target: root.audioSink?.audio ?? null

        function onVolumeChanged() {
            if (!root.audioReady)
                return;
            const vol = root.sinkVolumePercent()
            const isMuted = root.audioSink && root.audioSink.audio ? root.audioSink.audio.muted : false
            root.lastMuted = isMuted
            if (!isNaN(vol) && vol !== root.lastVolume) {
                root.lastVolume = vol
                root.show("volume", vol, isMuted ? "󰖁" : "󰕾")
            }
        }

        function onMutedChanged() {
            if (!root.audioReady)
                return;
            const isMuted = root.audioSink && root.audioSink.audio ? root.audioSink.audio.muted : false
            if (isMuted !== root.lastMuted) {
                root.lastMuted = isMuted
                root.show("volume", root.sinkVolumePercent(), isMuted ? "󰖁" : "󰕾")
            }
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root.syncSinkState()
        }
    }

    Component.onCompleted: syncSinkState()

    Timer {
        id: volumeFallbackWatcher
        interval: 750
        repeat: true
        running: true
        onTriggered: {
            if (!root.audioReady)
                return;
            const vol = root.sinkVolumePercent()
            const isMuted = root.audioSink && root.audioSink.audio ? root.audioSink.audio.muted : false
            const volumeChanged = !isNaN(vol) && vol !== root.lastVolume
            const muteChanged = isMuted !== root.lastMuted
            if (volumeChanged || muteChanged) {
                root.lastVolume = vol
                root.lastMuted = isMuted
                root.show("volume", vol, isMuted ? "󰖁" : "󰕾")
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
                Layout.preferredWidth: root.type === "media" ? -1 : 40
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
                visible: root.type !== "media"
            }

            Text {
                visible: root.type === "media"
                text: root.mediaSource ? (root.mediaTitle + " • " + root.mediaSource) : root.mediaTitle
                font.pixelSize: 13
                color: GlobalState.text
                elide: Text.ElideRight
                Layout.preferredWidth: 132
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
