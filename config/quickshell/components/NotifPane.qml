// NotifPane.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
        bottom: true
    }

    implicitWidth: 450
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    IpcHandler {
        target: "toggle-notifs"
        function toggle(): void { root.visible = !root.visible }
        function show(): void { root.visible = true }
        function hide(): void { root.visible = false }
    }

    NotifCenter {
        anchors.fill: parent
        anchors.margins: 12
        border.color: "#cba6f7"
        border.width: 1
    }
}
