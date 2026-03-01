// ControlCenter.qml
// Wallpaper picker overlay for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-wallpapers toggle
// Keybind example (hyprland.conf):
//   bind = SUPER, W, exec, qs ipc call toggle-wallpapers toggle
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer with a dim backdrop.
//   - FolderListModel scans ~/Pictures/wallpapers (falls back gracefully if the
//     folder doesn't exist — FolderListModel returns an empty model in that case).
//   - GridView renders Image thumbnails (aspect-fill, rounded corners).
//   - Clicking a thumbnail:
//       1. Runs `swww img <path> --transition-type grow` (sets wallpaper).
//       2. Runs `matugen image <path>` (regenerates colour scheme).
//   - Escape or clicking the backdrop dismisses the panel.
//   - Active wallpaper is highlighted with a mauve border.
//   - MUST NOT hang the UI if the folder doesn't exist or is empty.
//   - MUST NOT take focus when not visible (visible: false at start).
//
// MUST NOT use Waybar, Mako, or any component other than Quickshell primitives.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel 2.15
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // State
    // activeWallpaper tracks the path of the currently applied wallpaper so the
    // grid can highlight it. Persists across open/close cycles within a session.
    // ──────────────────────────────────────────────────────────────────────────
    property string activeWallpaper: ""

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-wallpapers"
    // Invoke: qs ipc call toggle-wallpapers toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-wallpapers"

        function toggle(): void {
            console.log("[ControlCenter] IPC toggle called — visible was: " + wallpaperWindow.visible);
            wallpaperWindow.visible = !wallpaperWindow.visible;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Wallpaper folder model
    //
    // FolderListModel watches the folder reactively; no polling needed.
    // If the folder does not exist it emits an empty model — the GridView will
    // show the empty-state message. showDirs:false hides subdirectories so only
    // image files appear.
    //
    // Supported extensions: jpg, jpeg, png, webp, gif (common wallpaper formats).
    // ──────────────────────────────────────────────────────────────────────────
    FolderListModel {
        id: wallpaperModel

        folder:   "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
        showDirs: false

        // Only surface image files — prevents stray .txt / .sh entries
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.avif"]

        // showHidden: false (default) — skip dot-files
        // sortField: "Name" (default) — deterministic ordering
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: apply wallpaper via swww
    // Command is set before running = true; previous run resets automatically.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: swwwProc

        onRunningChanged: {
            if (!running) {
                console.log("[ControlCenter] swwwProc finished — exit code: " + exitCode);
                if (exitCode === 0) {
                    // swww succeeded → now run matugen to regenerate colours
                    matugenProc.running = true;
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: regenerate colour scheme via matugen
    // Triggered automatically after swwwProc succeeds.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: matugenProc

        onRunningChanged: {
            if (!running) {
                console.log("[ControlCenter] matugenProc finished — exit code: " + exitCode);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: apply a wallpaper
    //   path  — absolute file path string
    // ──────────────────────────────────────────────────────────────────────────
    function applyWallpaper(path) {
        if (!path || path === "") {
            console.log("[ControlCenter] applyWallpaper: empty path — skipping");
            return;
        }

        console.log("[ControlCenter] applyWallpaper: " + path);
        root.activeWallpaper = path;

        // Build swww command — transition-type grow looks great for wallpaper picks
        swwwProc.command = [
            "swww", "img", path,
            "--transition-type", "grow",
            "--transition-pos",  "center"
        ];

        // Also pre-arm the matugen command (it will be triggered in swwwProc.onRunningChanged)
        matugenProc.command = ["matugen", "image", path];

        swwwProc.running = true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: wallpaperWindow

        // Hidden on startup — IPC toggle reveals it
        visible: false

        // Keyboard focus so Escape works
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-wallpapers"

        // Span the full screen
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Transparent — the visual background is inside
        color: "transparent"

        // Float above all windows without stealing exclusive zone space
        exclusionMode: ExclusionMode.Ignore

        // Escape → close overlay
        Keys.onEscapePressed: {
            console.log("[ControlCenter] Escape pressed — closing overlay");
            wallpaperWindow.visible = false;
        }

        // ── Dim backdrop (click outside card → close) ─────────────────────────
        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("[ControlCenter] backdrop clicked — closing overlay");
                wallpaperWindow.visible = false;
            }

            Rectangle {
                anchors.fill: parent
                color: "#cc000000"   // semi-transparent dark overlay
            }
        }

        // ── Centered picker card ──────────────────────────────────────────────
        Rectangle {
            id: pickerCard

            anchors.centerIn: parent
            width:  Math.min(parent.width  * 0.85, 960)
            height: Math.min(parent.height * 0.85, 720)

            radius: Globals.radiusLarge

            color:        Globals.colorBackground
            border.color: Globals.colorBorder
            border.width: 1

            // Swallow backdrop clicks so they don't close the overlay
            MouseArea {
                anchors.fill: parent
                onClicked: { /* swallow */ }
            }

            // ── Fade-in animation ─────────────────────────────────────────────
            opacity: wallpaperWindow.visible ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: Globals.animNormal; easing.type: Easing.OutCubic }
            }

            // Scale from slightly smaller on open
            transform: Scale {
                origin.x: pickerCard.width  / 2
                origin.y: pickerCard.height / 2
                xScale: wallpaperWindow.visible ? 1.0 : 0.92
                yScale: wallpaperWindow.visible ? 1.0 : 0.92
            }
            Behavior on transform.xScale {
                NumberAnimation { duration: Globals.animNormal; easing.type: Easing.OutCubic }
            }
            Behavior on transform.yScale {
                NumberAnimation { duration: Globals.animNormal; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: Globals.spacingLoose
                spacing:         Globals.spacingRelaxed

                // ── Header row ────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Globals.spacingNormal

                    // Icon + title
                    Text {
                        text:           "  Wallpapers"
                        color:          Globals.colorAccent
                        font.pixelSize: 15
                        font.bold:      true
                        Layout.fillWidth: true
                    }

                    // Wallpaper count badge
                    Rectangle {
                        width:  countLabel.implicitWidth + 16
                        height: 22
                        radius: 11
                        color:  Globals.colorSurface
                        visible: wallpaperModel.count > 0

                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text:             wallpaperModel.count + " images"
                            color:            Globals.colorTextDim
                            font.pixelSize:   11
                        }
                    }

                    // Close button
                    Rectangle {
                        width:  28
                        height: 28
                        radius: Globals.radiusSmall
                        color:  closeBtnHover.containsMouse
                                ? Globals.colorSurfaceRaised
                                : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Globals.animFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text:             "󰅖"
                            color:            closeBtnHover.containsMouse
                                              ? Globals.colorError
                                              : Globals.colorTextDim
                            font.pixelSize:   14

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }
                        }

                        MouseArea {
                            id: closeBtnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                console.log("[ControlCenter] close button clicked");
                                wallpaperWindow.visible = false;
                            }
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color:  Globals.colorBorder
                }

                // ── Active wallpaper hint ─────────────────────────────────────
                Text {
                    visible: root.activeWallpaper !== ""
                    text:    "  " + root.activeWallpaper.split("/").pop()
                    color:   Globals.colorTextDim
                    font.pixelSize: 11
                    elide:   Text.ElideMiddle
                    Layout.fillWidth: true
                }

                // ── Wallpaper grid ────────────────────────────────────────────
                //
                // cellWidth / cellHeight are fixed; the grid calculates columns
                // automatically based on the available width.  clip: true prevents
                // thumbnails from overflowing the card while scrolling.
                //
                // Empty-state message is shown when the folder is missing or empty.
                // ──────────────────────────────────────────────────────────────

                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    // ── Empty state ───────────────────────────────────────────
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Globals.spacingRelaxed
                        visible: wallpaperModel.count === 0

                        Text {
                            text: "󰋩"
                            color: Globals.colorTextDisabled
                            font.pixelSize: 48
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "No wallpapers found"
                            color: Globals.colorTextDim
                            font.pixelSize: 15
                            font.bold:      true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Add images to ~/Pictures/wallpapers"
                            color: Globals.colorTextDisabled
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // ── Scrollable wallpaper grid ─────────────────────────────
                    GridView {
                        id: wallpaperGrid

                        anchors.fill: parent
                        visible:      wallpaperModel.count > 0

                        model:    wallpaperModel

                        // Thumbnail size — 4 columns at 960 px wide card
                        cellWidth:  220
                        cellHeight: 148

                        clip:           true
                        boundsBehavior: Flickable.StopAtBounds

                        // Smooth scrolling deceleration
                        flickDeceleration: 1500
                        maximumFlickVelocity: 2400

                        // Scroll indicator
                        ScrollIndicator.vertical: ScrollIndicator {}

                        delegate: Item {
                            id: thumbDelegate

                            // Required FolderListModel roles
                            required property string fileName
                            required property string fileUrl
                            required property string filePath

                            width:  wallpaperGrid.cellWidth
                            height: wallpaperGrid.cellHeight

                            // ── Thumbnail container ───────────────────────────
                            Rectangle {
                                id: thumbFrame

                                anchors.fill:    parent
                                anchors.margins: 6

                                radius: Globals.radiusMedium
                                color:  Globals.colorSurface
                                clip:   true

                                // Active wallpaper → mauve highlight border
                                // Hovered         → subtle raised border
                                // Default          → normal border
                                readonly property bool isActive: root.activeWallpaper === thumbDelegate.filePath

                                border.color: isActive
                                              ? Globals.colorAccent
                                              : (thumbHover.containsMouse
                                                 ? Globals.colorSurfaceRaised
                                                 : Globals.colorBorder)
                                border.width: isActive ? 2 : 1

                                Behavior on border.color {
                                    ColorAnimation { duration: Globals.animFast }
                                }

                                // ── Thumbnail image ───────────────────────────
                                Image {
                                    id: thumbImage

                                    anchors.fill: parent

                                    source:          thumbDelegate.fileUrl
                                    sourceSize.width:  wallpaperGrid.cellWidth  * 2   // 2× for HiDPI
                                    sourceSize.height: wallpaperGrid.cellHeight * 2

                                    fillMode:     Image.PreserveAspectCrop
                                    asynchronous: true   // non-blocking thumbnail load
                                    cache:        true

                                    // ── Loading placeholder ───────────────────
                                    Rectangle {
                                        anchors.fill: parent
                                        color:        Globals.colorSurface
                                        visible:      thumbImage.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text:             thumbImage.status === Image.Error
                                                              ? "󰋩" : "󰔟"
                                            color:            Globals.colorTextDisabled
                                            font.pixelSize:   24
                                        }
                                    }

                                    // ── Hover brightness overlay ──────────────
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#33ffffff"   // 20% white tint
                                        opacity: thumbHover.containsMouse ? 1.0 : 0.0

                                        Behavior on opacity {
                                            NumberAnimation { duration: Globals.animFast }
                                        }
                                    }
                                }

                                // ── Active checkmark badge ────────────────────
                                Rectangle {
                                    anchors.top:         parent.top
                                    anchors.right:       parent.right
                                    anchors.topMargin:   6
                                    anchors.rightMargin: 6

                                    width:  22
                                    height: 22
                                    radius: 11
                                    color:  Globals.colorAccent
                                    visible: thumbFrame.isActive

                                    Text {
                                        anchors.centerIn: parent
                                        text:             "󰸞"   // checkmark glyph
                                        color:            Globals.colorBackground
                                        font.pixelSize:   12
                                    }
                                }

                                // ── Filename label (shown on hover) ───────────
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left:   parent.left
                                    anchors.right:  parent.right
                                    height:         fileLabel.implicitHeight + 10

                                    color:   "#cc000000"
                                    opacity: thumbHover.containsMouse ? 1.0 : 0.0
                                    // No radius on the label strip — clips flush with thumbFrame radius

                                    Behavior on opacity {
                                        NumberAnimation { duration: Globals.animFast }
                                    }

                                    Text {
                                        id: fileLabel
                                        anchors {
                                            verticalCenter: parent.verticalCenter
                                            left:           parent.left
                                            right:          parent.right
                                            leftMargin:     8
                                            rightMargin:    8
                                        }
                                        text:           thumbDelegate.fileName
                                        color:          "#cdd6f4"
                                        font.pixelSize: 10
                                        elide:          Text.ElideMiddle
                                    }
                                }

                                // ── Click handler ─────────────────────────────
                                MouseArea {
                                    id: thumbHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape:  Qt.PointingHandCursor

                                    onClicked: {
                                        console.log("[ControlCenter] thumbnail clicked: "
                                            + thumbDelegate.filePath);
                                        root.applyWallpaper(thumbDelegate.filePath);
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Footer: shortcut hints ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: [
                            { key: "Click", label: "apply wallpaper" },
                            { key: "Esc",   label: "close"           }
                        ]

                        Row {
                            required property var modelData
                            spacing: 4

                            Rectangle {
                                width:  hintKey.implicitWidth + 8
                                height: 18
                                radius: 4
                                color:  Globals.colorSurface

                                Text {
                                    id: hintKey
                                    anchors.centerIn: parent
                                    text:             modelData.key
                                    color:            Globals.colorTextDim
                                    font.pixelSize:   10
                                }
                            }

                            Text {
                                text:           modelData.label
                                color:          Globals.colorTextDisabled
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
