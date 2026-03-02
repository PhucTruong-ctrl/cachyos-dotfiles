// ThemePane.qml
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
    exclusionMode: ExclusionMode.Ignore

    IpcHandler {
        target: "toggle-theme"
        function toggle(): void { root.visible = !root.visible }
        function show(): void { root.visible = true }
        function hide(): void { root.visible = false }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "#1e1e2e"
        radius: 12
        border.color: "#cba6f7"
        border.width: 1
        
        ThemeMatrix {
            anchors.fill: parent
            anchors.margins: 12
            cellWidth: 194
            cellHeight: 120
            clip: true
        }
    }
}
