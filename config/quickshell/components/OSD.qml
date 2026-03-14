// OSD.qml — end-4 style OSD controller adapted for this repo.
// Full replacement of local event-bus OSD stack:
// - listens directly to PipeWire volume/mute deltas
// - polls brightnessctl for brightness deltas (works on brightnessctl 0.5+)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../services"

Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property bool active: false
    property string currentIndicator: "volume"

    property int volumePercent: 0
    property bool volumeMuted: false
    property int brightnessPercent: 0

    property bool _volumePrimed: false
    property bool _brightnessPrimed: false
    property bool _forceShowVolumeNext: false
    property bool _forceShowBrightnessNext: false

    function parseAudioLine(line) {
        const trimmed = line.trim()
        if (!trimmed)
            return null

        // pamixer --get-volume --get-mute usually prints: "false 55"
        // Accept either ordering just in case.
        const boolMatch = trimmed.match(/\b(true|false)\b/)
        const intMatch = trimmed.match(/\b(\d{1,3})\b/)
        if (!boolMatch || !intMatch)
            return null

        const muted = boolMatch[1] === "true"
        const vol = Math.max(0, Math.min(100, parseInt(intMatch[1], 10)))
        if (isNaN(vol))
            return null

        return {
            muted,
            vol
        }
    }

    function triggerVolume(newPercent, muted): void {
        root.currentIndicator = "volume"
        root.volumePercent = Math.max(0, Math.min(100, newPercent))
        root.volumeMuted = !!muted
        root.active = true
    }

    function triggerBrightness(newPercent): void {
        root.currentIndicator = "brightness"
        root.brightnessPercent = Math.max(0, Math.min(100, newPercent))
        root.active = true
    }

    function requestVolumeShow(): void {
        root._forceShowVolumeNext = true
        audioSample.running = false
        audioSample.running = true
    }

    function requestBrightnessShow(): void {
        root._forceShowBrightnessNext = true
        brightnessSample.running = false
        brightnessSample.running = true
    }

    IpcHandler {
        target: "osd"

        function showVolume(): void {
            root.requestVolumeShow()
        }

        function showBrightness(): void {
            root.requestBrightnessShow()
        }
    }

    function parseBrightnessLine(line) {
        const parts = line.split(",")
        if (parts.length < 4)
            return null

        const current = parseInt(parts[2], 10)
        const maxField = parts.length >= 5 ? parts[4] : parts[3]
        const max = parseInt(maxField, 10)
        if (isNaN(current) || isNaN(max) || max <= 0)
            return null

        return Math.max(0, Math.min(100, Math.round((current / max) * 100)))
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null

        function onVolumeChanged() {
            const sinkAudio = Pipewire.defaultAudioSink?.audio
            if (!sinkAudio)
                return
            const vol = Math.round((sinkAudio.volume || 0) * 100)
            const muted = !!sinkAudio.muted
            if (!root._volumePrimed) {
                root._volumePrimed = true
                root.volumePercent = vol
                root.volumeMuted = muted
                return
            }
            if (vol === root.volumePercent && muted === root.volumeMuted)
                return
            root.triggerVolume(vol, muted)
        }

        function onMutedChanged() {
            onVolumeChanged()
        }
    }

    Process {
        id: audioSample
        command: ["pamixer", "--get-volume", "--get-mute"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parsed = root.parseAudioLine(data)
                if (!parsed)
                    return

                if (!root._volumePrimed) {
                    root._volumePrimed = true
                    root.volumePercent = parsed.vol
                    root.volumeMuted = parsed.muted
                    if (root._forceShowVolumeNext) {
                        root._forceShowVolumeNext = false
                        root.triggerVolume(parsed.vol, parsed.muted)
                    }
                    return
                }

                if (!root._forceShowVolumeNext && parsed.vol === root.volumePercent && parsed.muted === root.volumeMuted)
                    return

                root._forceShowVolumeNext = false
                root.triggerVolume(parsed.vol, parsed.muted)
            }
        }
    }

    Process {
        id: brightnessSample
        command: ["brightnessctl", "-m"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (!line)
                    return
                const pct = root.parseBrightnessLine(line)
                if (pct === null)
                    return

                if (!root._brightnessPrimed) {
                    root._brightnessPrimed = true
                    root.brightnessPercent = pct
                    if (root._forceShowBrightnessNext) {
                        root._forceShowBrightnessNext = false
                        root.triggerBrightness(pct)
                    }
                    return
                }

                if (!root._forceShowBrightnessNext && pct === root.brightnessPercent)
                    return

                root._forceShowBrightnessNext = false
                root.triggerBrightness(pct)
            }
        }
    }

    Timer {
        id: audioPoller
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            audioSample.running = false
            audioSample.running = true
        }
    }

    Timer {
        id: brightnessPoller
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            brightnessSample.running = false
            brightnessSample.running = true
        }
    }

    Loader {
        id: panelLoader
        active: root.active

        sourceComponent: PanelWindow {
            id: panelWindow

            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            implicitWidth: indicatorLoader.item ? indicatorLoader.item.implicitWidth : Appearance.osdWidth
            implicitHeight: indicatorLoader.item ? indicatorLoader.item.implicitHeight : Appearance.osdHeight

            anchors {
                bottom: true
                left: true
                right: true
            }

            margins {
                bottom: Appearance.osdBottomMargin
                left: Math.round((Screen.width - panelWindow.implicitWidth) / 2)
                right: Math.round((Screen.width - panelWindow.implicitWidth) / 2)
            }

            screen: root.focusedScreen

            mask: Region {
                item: indicatorLoader
            }

            Loader {
                id: indicatorLoader
                anchors.fill: parent

                sourceComponent: root.currentIndicator === "brightness" ? brightnessIndicatorComponent : volumeIndicatorComponent
            }
        }
    }

    Component {
        id: volumeIndicatorComponent

        VolumeOSD {
            iconName: root.volumeMuted ? "󰖁" : "󰕾"
            value: root.volumePercent / 100
            onClosed: root.active = false
        }
    }

    Component {
        id: brightnessIndicatorComponent

        BrightnessOSD {
            iconName: "󰃠"
            value: root.brightnessPercent / 100
            onClosed: root.active = false
        }
    }
}
