import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

Scope {
    id: calendarRoot

    IpcHandler {
        target: "toggle-calendar"
        function toggle(): void {
            calendarWindow.visible = !calendarWindow.visible
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
            onClicked:    calendarWindow.visible = false
        }

        // Calendar panel — positioned at top-right
        Rectangle {
            anchors.right:       parent.right
            anchors.top:         parent.top
            anchors.rightMargin: 12
            anchors.topMargin:   45
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
