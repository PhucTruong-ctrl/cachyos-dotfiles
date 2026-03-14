import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: root

    required property string iconName
    property real value: 0
    property bool showNumber: true
    signal closed()

    property int closeAnimDuration: 160

    implicitWidth: root.showNumber ? 210 : 184
    implicitHeight: 56

    function close(): void {
        closeAnimation.restart()
    }

    Timer {
        id: autoCloseTimer
        running: true
        interval: Appearance.osdHideDelay
        repeat: false
        onTriggered: root.close()
    }

    SequentialAnimation {
        id: closeAnimation
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0
            duration: root.closeAnimDuration
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                content.opacity = 1
                root.closed()
            }
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        radius: Appearance.osdRadius
        color: GlobalState.osdBackground
        border.color: Qt.rgba(GlobalState.osdTrack.r, GlobalState.osdTrack.g, GlobalState.osdTrack.b, 0.9)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: root.iconName
                font.pixelSize: 20
                font.family: "monospace"
                color: GlobalState.osdIcon
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.osdBarHeight
                color: GlobalState.osdTrack
                radius: Appearance.osdBarRadius
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: Math.max(0, Math.min(1, root.value)) * parent.width
                    height: parent.height
                    color: GlobalState.osdFill
                    radius: Appearance.osdBarRadius
                }
            }

            Text {
                visible: root.showNumber
                text: Math.round(Math.max(0, Math.min(1, root.value)) * 100)
                font.pixelSize: Appearance.osdValueSize
                font.bold: true
                color: GlobalState.osdText
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
