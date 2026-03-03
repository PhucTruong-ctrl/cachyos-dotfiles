// MediaPane.qml — Detailed MPRIS media control popup panel
//
// Layout:
//   - Album art image (rounded corners, 160×160)
//   - Title + artist text
//   - Progress bar (indeterminate — no position polling to keep it simple)
//   - Prev / Play-Pause / Next controls
//
// Toggle via:  qs ipc call toggle-media toggle
// Namespace:   quickshell-media  (for Hyprland blur layerrule)
// Click-outside-to-close backdrop (same pattern as ControlCenter)
//
// Colors: all from GlobalState
// Animations: all durations/curves from Appearance

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

PanelWindow {
    id: root

    // ── Full-screen so backdrop can dismiss on click-outside ──────────────────
    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace:     "quickshell-media"
    exclusionMode:               ExclusionMode.Ignore

    color:   "transparent"
    visible: false

    // ── Open / close state (driven by PopupStateService) ─────────────────────
    property bool open: false

    // Sync open state from PopupStateService (single-open coordination)
    Connections {
        target: PopupStateService
        function onOpenPopupIdChanged() {
            root.open = (PopupStateService.openPopupId === "media")
        }
    }

    onOpenChanged: {
        if (open) {
            contentRect.opacity = 0
            contentRect.scale   = 0.92
            visible = true
            fadeInAnim.restart()
            scaleInAnim.restart()
        } else {
            fadeOutAnim.restart()
            scaleOutAnim.restart()
        }
    }

    // ── IPC handler ───────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-media"
        function toggle(): void {
            PopupStateService.toggleExclusive("media")
        }
    }

    // ── Fade-in ───────────────────────────────────────────────────────────────
    NumberAnimation {
        id:        fadeInAnim
        target:    contentRect
        property:  "opacity"
        from:      0
        to:        1
        duration:  Appearance.popupFade
        easing.type: Appearance.standardDecel
    }

    NumberAnimation {
        id:        scaleInAnim
        target:    contentRect
        property:  "scale"
        from:      0.92
        to:        1.0
        duration:  Appearance.contentSwitch
        easing.type: Appearance.standardDecel
    }

    // ── Fade-out ──────────────────────────────────────────────────────────────
    NumberAnimation {
        id:        fadeOutAnim
        target:    contentRect
        property:  "opacity"
        from:      1
        to:        0
        duration:  Appearance.popupFade
        easing.type: Appearance.standardAccel
        onStopped: root.visible = false
    }

    NumberAnimation {
        id:        scaleOutAnim
        target:    contentRect
        property:  "scale"
        from:      1.0
        to:        0.92
        duration:  Appearance.contentSwitch
        easing.type: Appearance.standardAccel
    }

    // ── Backdrop: click outside closes the panel ──────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked:    PopupStateService.closeAll()
    }

    // ── Main content rectangle ────────────────────────────────────────────────
    Rectangle {
        id:     contentRect
        width:  300
        height: mediaColumn.implicitHeight + 32

        // Anchor-driven position: center over trigger icon, just below bar
        x: PopupAnchorService.popupXFor(width, parent.width)
        y: PopupAnchorService.barY + 4

        color:        Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
        radius:       Appearance.panelRadius
        border.color: GlobalState.matugenPrimary
        border.width: 1

        opacity: 0
        scale:   0.92

        // Absorb clicks — prevent backdrop from firing inside content
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id:              mediaColumn
            anchors.top:     parent.top
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.margins: 16
            spacing:         12

            // ── Header row ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:             "󰎇  Media"
                    color:            GlobalState.text
                    font.pixelSize:   15
                    font.bold:        true
                    font.family:      "monospace"
                    Layout.fillWidth: true
                }

                Rectangle {
                    width:  24
                    height: 24
                    radius: 4
                    color:  closeHover.containsMouse ? GlobalState.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text:             "✕"
                        color:            GlobalState.subtext0
                        font.pixelSize:   13
                    }

                    HoverHandler { id: closeHover }

                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     PopupStateService.closeAll()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                color:                  GlobalState.surface1
            }

            // ── No-player fallback ────────────────────────────────────────────
            Text {
                visible:          !MediaService.hasPlayer
                text:             "No media playing"
                color:            GlobalState.subtext0
                font.pixelSize:   13
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }

            // ── Media content (only when player is active) ────────────────────
            ColumnLayout {
                visible:          MediaService.hasPlayer
                Layout.fillWidth: true
                spacing:          12

                // Album art
                Rectangle {
                    Layout.alignment:    Qt.AlignHCenter
                    width:               160
                    height:              160
                    radius:              Appearance.panelRadius
                    color:               GlobalState.surface0
                    clip:                true

                    Image {
                        id:            albumArt
                        anchors.fill:  parent
                        source:        MediaService.albumArtUrl
                        fillMode:      Image.PreserveAspectCrop
                        smooth:        true
                        visible:       status === Image.Ready

                        Behavior on source {
                            // Fade when album art changes
                            PropertyAnimation { duration: Appearance.contentSwitch }
                        }
                    }

                    // Fallback icon when no album art
                    Text {
                        anchors.centerIn: parent
                        visible:          albumArt.status !== Image.Ready
                        text:             "󰎆"    // nf-md-music
                        color:            GlobalState.overlay1
                        font.pixelSize:   64
                        font.family:      "monospace"
                    }
                }

                // Title
                Text {
                    text:             MediaService.title.length > 0 ? MediaService.title : "Unknown Title"
                    color:            GlobalState.text
                    font.pixelSize:   15
                    font.bold:        true
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide:            Text.ElideRight
                    maximumLineCount: 1
                }

                // Artist
                Text {
                    text:             MediaService.artist.length > 0 ? MediaService.artist : "Unknown Artist"
                    color:            GlobalState.subtext1
                    font.pixelSize:   12
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide:            Text.ElideRight
                    maximumLineCount: 1
                }

                // Player name badge
                Text {
                    text:             MediaService.playerName
                    color:            GlobalState.overlay1
                    font.pixelSize:   10
                    Layout.alignment: Qt.AlignHCenter
                    visible:          MediaService.playerName.length > 0
                }

                // Progress bar (visual only — no position tracking)
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 4
                    radius:                 2
                    color:                  GlobalState.surface1

                    Rectangle {
                        width:   parent.width * 0.4   // static placeholder
                        height:  parent.height
                        radius:  2
                        color:   GlobalState.matugenPrimary
                        visible: MediaService.playbackStatus === "Playing"
                    }
                }

                // Playback controls: Prev / Play-Pause / Next
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing:          24

                    // Previous
                    Rectangle {
                        width:   40
                        height:  40
                        radius:  20
                        color:   prevHover.containsMouse ? GlobalState.surface1 : GlobalState.surface0

                        Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                        Text {
                            anchors.centerIn: parent
                            text:             "󰒮"   // nf-md-skip_previous
                            color:            GlobalState.matugenOnSurface
                            font.pixelSize:   18
                            font.family:      "monospace"
                        }

                        HoverHandler { id: prevHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    MediaService.previous()
                        }
                    }

                    // Play / Pause
                    Rectangle {
                        width:   48
                        height:  48
                        radius:  24
                        color:   playHover.containsMouse ? GlobalState.matugenSurfaceVariant : GlobalState.matugenPrimary

                        Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                        Text {
                            anchors.centerIn: parent
                            text:             MediaService.playbackStatus === "Playing" ? "󰏤" : "󰐊"
                            color:            GlobalState.matugenOnPrimary
                            font.pixelSize:   22
                            font.family:      "monospace"
                        }

                        HoverHandler { id: playHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    MediaService.playPause()
                        }
                    }

                    // Next
                    Rectangle {
                        width:   40
                        height:  40
                        radius:  20
                        color:   nextHover.containsMouse ? GlobalState.surface1 : GlobalState.surface0

                        Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                        Text {
                            anchors.centerIn: parent
                            text:             "󰒭"   // nf-md-skip_next
                            color:            GlobalState.matugenOnSurface
                            font.pixelSize:   18
                            font.family:      "monospace"
                        }

                        HoverHandler { id: nextHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    MediaService.next()
                        }
                    }
                }
            }

            // Bottom spacer
            Item { Layout.preferredHeight: 4 }
        }
    }
}
