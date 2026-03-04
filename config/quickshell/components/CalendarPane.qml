// CalendarPane.qml — Clock-driven popup that shows current month/day info beneath the bar.
// Visibility follows PopupStateService; placement uses PopupAnchorService coordinates.
// IPC: qs ipc call toggle-calendar toggle.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

Scope {
    id: calendarRoot

    // Sync visibility from PopupStateService (single-open coordination)
    Connections {
        target: PopupStateService
        function onOpenPopupIdChanged() {
            calendarWindow.visible = (PopupStateService.openPopupId === "calendar")
        }
    }

    IpcHandler {
        target: "toggle-calendar"
        function toggle(): void {
            PopupStateService.toggleExclusive("calendar")
        }
    }

    PanelWindow {
        id: calendarWindow
        visible: false
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "quickshell-calendar"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Backdrop — click outside calendar closes it
        MouseArea {
            anchors.fill: parent
            onClicked:    PopupStateService.closeAll()
        }

        // Calendar panel — positioned below trigger icon
        Rectangle {
            x:      PopupAnchorService.popupXFor(320, parent.width)
            y:      PopupAnchorService.barY + 4
            width:  320
            height: 320
            color: Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
            radius: Appearance.panelRadius
            border.color: GlobalState.mauve
            border.width: 1

            MouseArea { anchors.fill: parent } // absorb clicks

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12

                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: Qt.locale()
                    
                    delegate: Text {
                        text: model.shortName
                        color: GlobalState.subtext1
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MonthGrid {
                    id: control
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    locale: Qt.locale()
                    
                    delegate: Text {
                        text: model.day
                        color: model.today ? GlobalState.mauve : (model.month === control.month ? GlobalState.text : GlobalState.overlay0)
                        font.pixelSize: 14
                        font.bold: model.today
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 4
                            color: "transparent"
                            border.color: GlobalState.mauve
                            border.width: 1
                            visible: model.today
                        }
                    }
                }
            }
        }
    }
}
