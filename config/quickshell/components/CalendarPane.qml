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
        implicitWidth: 320
        implicitHeight: 320
        visible: false
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            right: true
        }

        margins {
            top: 45
            right: 12
        }

        Rectangle {
            anchors.fill: parent
            color: GlobalState.base
            radius: 12
            border.color: GlobalState.mauve
            border.width: 1

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
