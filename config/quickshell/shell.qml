import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        height: 30
        color: "#282a36"

        Text {
            text: "Hello from Quickshell!"
            color: "#f8f8f2"
            anchors.centerIn: parent
        }
    }
}
