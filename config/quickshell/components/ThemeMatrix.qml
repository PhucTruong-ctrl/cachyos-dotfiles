pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../services"

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
            color: GlobalState.base
            radius: 8
            border.color: hoverArea.containsMouse ? GlobalState.mauve : "transparent"
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: fileUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: hoverArea.containsMouse ? 0.8 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: Appearance.popupFade }
                }
            }
            
            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Derive absolute path from fileUrl (known-good) instead of filePath
                    var wallpaperPath = fileUrl.toString().replace("file://", "");
                    var scriptPath = Qt.resolvedUrl("../scripts/wallpaper-engine.sh").toString().replace("file://", "");
                    console.log("[ThemeMatrix] wallpaperPath:", wallpaperPath);
                    console.log("[ThemeMatrix] scriptPath:", scriptPath);
                    wpProcess.command = ["bash", scriptPath, wallpaperPath];
                    wpProcess.running = true;
                }
            }
        }
    }

    Process {
        id: wpProcess

        stdout: SplitParser {
            onRead: data => console.log("[ThemeMatrix] stdout:", data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("[ThemeMatrix] stderr:", data)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[ThemeMatrix] wallpaper-engine.sh failed with exit code:", exitCode);
            } else {
                console.log("[ThemeMatrix] wallpaper-engine.sh completed successfully. Triggering color reload directly.");
                // Ambxst approach: Direct invocation, no IPC needed.
                GlobalState.reloadColors();
            }
        }
    }
}
