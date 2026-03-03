// ThemePane.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import Quickshell.Wayland
import Quickshell.Io

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
    WlrLayershell.namespace: "quickshell-theme"
    exclusionMode: ExclusionMode.Ignore

    // Sync visibility from PopupStateService (single-open coordination)
    Connections {
        target: PopupStateService
        function onOpenPopupIdChanged() {
            root.visible = (PopupStateService.openPopupId === "theme")
        }
    }

    IpcHandler {
        target: "toggle-theme"
        function toggle(): void { PopupStateService.toggleExclusive("theme") }
        function show(): void   { PopupStateService.openExclusive("theme") }
        function hide(): void   {
            if (PopupStateService.openPopupId === "theme") PopupStateService.closeAll()
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

        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            color: Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
            radius: Appearance.panelRadius
            border.color: GlobalState.matugenPrimary
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
}
