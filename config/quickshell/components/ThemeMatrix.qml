pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel

GridView {
    id: root

    model: FolderListModel {
        folder: "file:///home/user/Pictures/Wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
    }

    cellWidth: 160
    cellHeight: 90

    delegate: Item {
        width: root.cellWidth
        height: root.cellHeight

        Image {
            anchors.fill: parent
            anchors.margins: 5
            source: fileUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
