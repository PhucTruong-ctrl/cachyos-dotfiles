// ThemeMatrix.qml — Wallpaper grid selector driving Matugen/GlobalState colors.
// Reads wallpapers via Io.DirectoryModel and updates GlobalState on selection.
// Used by ThemePane + Dashboard for wallpaper/theme management.

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../services"

GridView {
    id: root

    property string activeWallpaperPath: ""
    property string wallpapersDirectoryPath: Quickshell.env("HOME") + "/Wallpapers"

    function ensureBackgroundThumbnails() {
        if (thumbnailBatchProcess.running || root.count === 0) {
            return;
        }

        thumbnailBatchProcess.command = [
            "bash",
            root.normalizeWallpaperPath(Qt.resolvedUrl("../scripts/wallpaper-thumbnail.sh")),
            "--directory",
            root.wallpapersDirectoryPath,
            "--size",
            "large"
        ];
        thumbnailBatchProcess.running = true;
    }

    function encodePathSegment(segment) {
        return encodeURIComponent(segment).replace(/[!'()*]/g, function(char) {
            return "%" + char.charCodeAt(0).toString(16).toUpperCase();
        });
    }

    function normalizeWallpaperPath(wallpaperSource) {
        if (wallpaperSource === undefined || wallpaperSource === null) {
            return "";
        }

        var normalizedPath = wallpaperSource.toString().trim();

        if (normalizedPath.startsWith("file://")) {
            normalizedPath = decodeURIComponent(normalizedPath.replace(/^file:\/\//, ""));
        }

        return normalizedPath;
    }

    function canonicalThumbnailUri(wallpaperUrl) {
        var absolutePath = normalizeWallpaperPath(wallpaperUrl);
        var encodedPath = absolutePath.split("/").map(function(segment) {
            return encodePathSegment(segment);
        }).join("/");

        return "file://" + encodedPath;
    }

    function thumbnailCacheSource(thumbnailHash) {
        var thumbnailPath = Quickshell.env("HOME") + "/.cache/thumbnails/large/" + thumbnailHash + ".png";
        var encodedPath = thumbnailPath.split("/").map(function(segment) {
            return encodePathSegment(segment);
        }).join("/");

        return "file://" + encodedPath;
    }

    model: FolderListModel {
        folder: "file://" + root.wallpapersDirectoryPath
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
    }

    cellWidth: 160
    cellHeight: 120
    cacheBuffer: cellHeight * 4

    Component.onCompleted: {
        activeWallpaperReader.running = true;
    }

    delegate: Item {
        required property url fileUrl
        required property string filePath
        property string normalizedFilePath: root.normalizeWallpaperPath(fileUrl)
        property bool thumbnailFailed: false
        property string thumbnailHash: Qt.md5(canonicalThumbnailUri(fileUrl))
        property string thumbnailSource: thumbnailCacheSource(thumbnailHash)
        property bool isActiveWallpaper: normalizedFilePath.length > 0 && normalizedFilePath === root.activeWallpaperPath

        onFileUrlChanged: thumbnailFailed = false

        width:  GridView.view.cellWidth
        height: GridView.view.cellHeight

        Rectangle {
            id: bgRect
            anchors.fill: parent
            anchors.margins: 4
            color: GlobalState.base
            radius: 8
            border.color: isActiveWallpaper ? GlobalState.matugenPrimary : (hoverArea.containsMouse ? Qt.alpha(GlobalState.matugenPrimary, 0.45) : "transparent")
            border.width: isActiveWallpaper ? 3 : 1
            clip: true

            Image {
                id: preview

                anchors.fill: parent
                source: thumbnailFailed ? fileUrl : thumbnailSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Math.max(1, Math.round(width))
                sourceSize.height: Math.max(1, Math.round(height))
                opacity: status === Image.Ready ? (hoverArea.containsMouse ? 0.8 : 1.0) : 0.0

                onStatusChanged: {
                    if (!thumbnailFailed && (status === Image.Error || status === Image.Null)) {
                        thumbnailFailed = true;
                    }
                }

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
                    var wallpaperPath = normalizedFilePath;
                    var scriptPath = root.normalizeWallpaperPath(Qt.resolvedUrl("../scripts/wallpaper-engine.sh"));
                    root.activeWallpaperPath = normalizedFilePath;
                    console.log("[ThemeMatrix] wallpaperPath:", wallpaperPath);
                    console.log("[ThemeMatrix] scriptPath:", scriptPath);
                    wpProcess.command = ["bash", scriptPath, wallpaperPath];
                    wpProcess.running = true;
                }
            }
        }
    }

    Process {
        id: activeWallpaperReader
        command: ["cat", Quickshell.env("HOME") + "/.cache/quickshell/current_wallpaper"]
        running: false

        stdout: SplitParser {
            onRead: data => root.activeWallpaperPath = root.normalizeWallpaperPath(data.trim())
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

    Process {
        id: thumbnailBatchProcess

        stdout: SplitParser {
            onRead: data => console.log("[ThemeMatrix] thumbnail stdout:", data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("[ThemeMatrix] thumbnail stderr:", data)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[ThemeMatrix] wallpaper-thumbnail.sh failed with exit code:", exitCode);
            }
        }
    }
}
