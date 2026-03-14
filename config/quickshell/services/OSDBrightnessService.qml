pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int lastPercent: -1
    property string lastDeviceKey: ""
    property int pendingPercent: -1
    property bool pendingIsDdc: false
    property string pendingDeviceKey: ""
    property int ddcDebounceMs: 300

    function flushPending(): void {
        if (root.pendingPercent < 0)
            return;
        const value = root.pendingPercent
        root.pendingPercent = -1
        root.lastPercent = value
        OSDEventBus.publishBrightness(value, "󰃠", {
            source: root.pendingIsDdc ? "ddc" : "backlight",
            device: root.pendingDeviceKey
        })
    }

    function schedulePublish(percent, isDdc, deviceKey): void {
        root.pendingPercent = percent
        root.pendingIsDdc = isDdc
        root.pendingDeviceKey = deviceKey
        if (isDdc)
            publishDebounce.restart()
        else
            root.flushPending()
    }

    Process {
        id: brightnessStream
        command: ["bash", "-lc", "brightnessctl -m --watch"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (!line)
                    return;
                const parts = line.split(",")
                if (parts.length < 4)
                    return;
                const kind = parts[0].trim().toLowerCase()
                const device = parts[1].trim()
                const cur = parseInt(parts[2], 10)
                const max = parseInt(parts[3], 10)
                if (isNaN(cur) || isNaN(max) || max <= 0)
                    return;
                const pct = Math.max(0, Math.min(100, Math.round((cur / max) * 100)))
                const deviceKey = `${kind}:${device}`
                if (deviceKey !== root.lastDeviceKey) {
                    root.lastDeviceKey = deviceKey
                    root.lastPercent = -1
                }
                if (root.lastPercent === -1) {
                    root.lastPercent = pct
                    return;
                }
                if (pct === root.lastPercent)
                    return;
                root.schedulePublish(pct, kind === "ddcutil", deviceKey)
            }
        }
    }

    Timer {
        id: publishDebounce
        interval: root.pendingIsDdc ? root.ddcDebounceMs : 0
        repeat: false
        onTriggered: root.flushPending()
    }
}
