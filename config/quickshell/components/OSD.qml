// OSD.qml — Volume/brightness on-screen display spawned by hardware key events.
// Uses hardware listeners + timers to show transient overlays near the bar.
// Colors + blur align with GlobalState and Appearance.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-osd"
    exclusionMode: ExclusionMode.Ignore

    // Center-bottom positioning
    implicitWidth: Appearance.osdWidth
    implicitHeight: Appearance.osdHeight

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        bottom: Appearance.osdBottomMargin
        left: Math.round((Screen.width - Appearance.osdWidth) / 2)
        right: Math.round((Screen.width - Appearance.osdWidth) / 2)
    }

    color: "transparent"

    property string icon: "󰕾"
    property int value: 0
    property string type: "volume"
    property string label: ""
    property var eventSource: GlobalState

    // ── OSD Visibility Controller ───────────────────────────────────────────
    property bool active: false
    visible: active

    Timer {
        id: hideTimer
        interval: Appearance.osdHideDelay
        onTriggered: root.active = false
    }

    function show(newType, newValue, newIcon) {
        root.type = newType
        root.value = newValue
        root.icon = newIcon
        root.active = true
        hideTimer.restart()
    }

    function normalizeEvent(event) {
        if (!event || typeof event !== "object")
            return null

        const eventType = typeof event.type === "string" && event.type.length > 0 ? event.type : typeof event.kind === "string" ? event.kind : ""
        if (eventType.length === 0)
            return null

        if (typeof event.value !== "number" || isNaN(event.value))
            return null

        const clampedValue = Math.round(Math.max(0, Math.min(100, event.value)))
        const eventIcon = typeof event.icon === "string" && event.icon.length > 0 ? event.icon : root.icon
        const eventLabel = typeof event.label === "string" ? event.label : ""

        return {
            "type": eventType,
            "value": clampedValue,
            "icon": eventIcon,
            "label": eventLabel
        }
    }

    function showFromEvent(event) {
        const normalized = root.normalizeEvent(event)
        if (!normalized)
            return

        root.label = normalized.label
        root.show(normalized.type, normalized.value, normalized.icon)
    }

    Connections {
        target: root.eventSource

        function onOsdEventChanged() {
            if (!root.eventSource)
                return;
            const event = root.eventSource.osdEvent
            root.showFromEvent(event)
        }
    }

    // ── UI Layout ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.osdRadius
        color: GlobalState.osdBackground

        RowLayout {
            anchors.fill: parent
            anchors.margins: Appearance.osdContentMargin
            spacing: Appearance.osdContentSpacing

            Text {
                text: root.icon
                font.pixelSize: Appearance.osdIconSize
                font.family: "monospace"
                color: GlobalState.osdIcon
                Layout.alignment: Qt.AlignVCenter
            }

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.osdBarHeight
                color: GlobalState.osdTrack
                radius: Appearance.osdBarRadius
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: (root.value / 100) * parent.width
                    height: parent.height
                    color: GlobalState.osdFill
                    radius: Appearance.osdBarRadius
                }
            }

            Text {
                text: root.value + "%"
                font.pixelSize: Appearance.osdValueSize
                font.bold: true
                color: GlobalState.osdText
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
