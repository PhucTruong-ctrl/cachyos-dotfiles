import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

Scope {
    id: calendarRoot

    IpcHandler {
        name: "toggle-calendar"
        onMessage: (message) => {
            if (message === "toggle") {
                calendarWindow.visible = !calendarWindow.visible
            }
        }
    }

    PopupWindow {
        id: calendarWindow
        width: 320
        height: 320
        visible: false
        color: "#1e1e2e" // Catppuccin Mocha base
        
        // Appear below the top bar (which is 40px)
        anchors {
            top: true
            right: true
        }
        
        // Push it slightly below the bar and padding from the right
        margins.top: 45
        margins.right: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale()
                
                delegate: Text {
                    text: model.shortName
                    color: "#bac2de"
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
                    color: model.today ? "#cba6f7" : (model.month === control.month ? "#cdd6f4" : "#6c7086")
                    font.pixelSize: 14
                    font.bold: model.today
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 4
                        color: "transparent"
                        border.color: "#cba6f7"
                        border.width: 1
                        visible: model.today
                    }
                }
            }
        }
    }
}
