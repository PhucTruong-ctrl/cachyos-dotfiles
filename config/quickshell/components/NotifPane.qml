// NotifPane.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

PanelWindow {
    id: root

    anchors {
        top:    true
        right:  true
        bottom: true
        left:   true
    }

    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    IpcHandler {
        target: "toggle-notifs"
        function toggle(): void { root.visible = !root.visible }
        function show(): void { root.visible = true }
        function hide(): void { root.visible = false }
    }

    // Backdrop — click outside closes the panel
    MouseArea {
        anchors.fill: parent
        onClicked:    root.visible = false
    }

    // Panel content — right-side strip, absorbs clicks inside
    Rectangle {
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:  450
        color:  "transparent"

        MouseArea { anchors.fill: parent } // absorb clicks

        NotifCenter {
            anchors.fill: parent
            anchors.margins: 12
            border.color: GlobalState.matugenPrimary
            border.width: 1
        }
    }
}
