// NotifCenter.qml
// The Notification Center UI component for Quickshell Dashboard.
// Shows a history of received notifications managed by NotifStore.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../services"

Rectangle {
    id: root

    // Catppuccin Mocha base color
    color: GlobalState.base
    radius: 12

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Notification Center"
                color: GlobalState.text // text
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                width: clearLabel.implicitWidth + 24
                height: 32
                radius: 6
                color: clearArea.containsMouse ? GlobalState.surface0 : GlobalState.mantle
                border.color: GlobalState.surface1
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: Appearance.popupFade }
                }

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear All"
                    color: GlobalState.red // red
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("[NotifCenter] clearing all notifications");
                        NotifStore.clearAll();
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: GlobalState.surface0 // surface0
        }

        // Notification List
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            model: NotifStore.notifModel

            // Placeholder when empty
            Text {
                anchors.centerIn: parent
                text: "No notifications"
                color: GlobalState.overlay0 // overlay0
                font.pixelSize: 14
                visible: notifList.count === 0
            }

            delegate: Rectangle {
                width: notifList.width
                height: contentCol.implicitHeight + 16
                radius: 8
                color: GlobalState.mantle // mantle
                border.color: GlobalState.surface0 // surface0
                border.width: 1

                readonly property color urgencyColor: {
                    const u = model.urgency;
                    if (u === NotificationUrgency.Critical) return GlobalState.red       // red
                    if (u === NotificationUrgency.Low)      return GlobalState.overlay0  // overlay0
                    return GlobalState.mauve   // mauve
                }

                Rectangle {
                    width: 3
                    height: parent.height - 16
                    radius: 2
                    color: urgencyColor
                    anchors {
                        left: parent.left
                        leftMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                }

                ColumnLayout {
                    id: contentCol
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 8
                        leftMargin: 12
                    }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Item {
                            width: 16
                            height: 16
                            Layout.alignment: Qt.AlignVCenter

                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(model.appIcon ?? "", true)
                                backer.sourceSize.width: 16
                                backer.sourceSize.height: 16
                                visible: (model.appIcon ?? "") !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰂚" // bell
                                color: urgencyColor
                                font.pixelSize: 12
                                visible: (model.appIcon ?? "") === ""
                            }
                        }

                        Text {
                            text: model.appName ?? "Unknown"
                            color: GlobalState.subtext0 // subtext0
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: {
                                const d = new Date(model.timestamp);
                                return d.getHours().toString().padStart(2, '0') + ":" + 
                                       d.getMinutes().toString().padStart(2, '0');
                            }
                            color: GlobalState.overlay0 // overlay0
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Text {
                        text: model.summary ?? ""
                        color: GlobalState.text // text
                        font.pixelSize: 13
                        font.bold: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        visible: model.summary !== ""
                    }

                    Text {
                        text: model.body ?? ""
                        color: GlobalState.subtext1 // subtext1
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        visible: model.body !== ""
                    }
                }
            }

            add: Transition {
                NumberAnimation { properties: "opacity,x"; from: 0; duration: Appearance.contentSwitch; easing.type: Appearance.standardDecel }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Appearance.popupFade; easing.type: Appearance.standardAccel }
            }
        }
    }
}
