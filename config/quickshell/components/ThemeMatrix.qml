pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

GridView {
    id: root

    // NOTE: Replace with the actual home directory path
    model: FolderListModel {
        // Evaluate the home directory dynamically or use an explicit path
        folder: "file://" + Quickshell.env("HOME") + "/Wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
    }

    cellWidth: 160
    cellHeight: 120

    delegate: Item {
        required property url fileUrl
        required property string filePath

        width: root.cellWidth
        height: root.cellHeight

        Rectangle {
            id: bgRect
            anchors.fill: parent
            anchors.margins: 4
            color: "#1e1e2e"
            radius: 8
            border.color: hoverArea.containsMouse ? "#cba6f7" : "transparent"
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: fileUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: hoverArea.containsMouse ? 0.8 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }
            
            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    console.log("[ThemeMatrix] Activating wallpaper:", filePath);
                    wpProcess.command = ["bash", Quickshell.env("HOME") + "/cachyos-dotfiles/scripts/wallpaper-engine.sh", filePath];
                    wpProcess.running = true;
                }
            }
        }
    }

    Process {
        id: wpProcess
    }
}
