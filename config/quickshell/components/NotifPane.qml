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
        bottom: true
        left:   true
        right:  true
    }

    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-notifs"
    exclusionMode: ExclusionMode.Ignore

    // Sync visibility from PopupStateService (single-open coordination)
    Connections {
        target: PopupStateService
        function onOpenPopupIdChanged() {
            root.visible = (PopupStateService.openPopupId === "notifs")
        }
    }

    IpcHandler {
        target: "toggle-notifs"
        function toggle(): void { PopupStateService.toggleExclusive("notifs") }
        function show(): void   { PopupStateService.openExclusive("notifs") }
        function hide(): void   {
            if (PopupStateService.openPopupId === "notifs") PopupStateService.closeAll()
        }
    }

    // Backdrop — click outside closes the panel
    MouseArea {
        anchors.fill: parent
        onClicked:    PopupStateService.closeAll()
    }

    // Panel content — anchored below trigger icon, full height strip
    Rectangle {
        x:      PopupAnchorService.popupXFor(450, parent.width)
        y:      PopupAnchorService.barY + 4
        width:  450
        height: parent.height - PopupAnchorService.barY - 12
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
