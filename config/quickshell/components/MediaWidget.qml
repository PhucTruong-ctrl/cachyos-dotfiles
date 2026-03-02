// MediaWidget.qml — Compact MPRIS media widget for the Bar
//
// Shows: music icon + scrolling "title — artist" text + play/pause button
// Only visible when MediaService.hasPlayer is true.
// Click on text → opens MediaPane via IPC, anchored below this widget.
// Play/pause button toggles playback directly.
//
// Geometry wiring: setAnchor("media", ...) is called before toggling MediaPane
// so PopupAnchorService can position the pane directly below this widget.
//
// Colors: all from GlobalState
// Animations: all durations/curves from Appearance

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../services"

Item {
    id: root

    // Only show widget when a player is active
    visible: MediaService.hasPlayer
    width:   visible ? contentRow.implicitWidth + 8 : 0
    height:  40

    // IPC process to open the media pane
    Process {
        id: mediaPaneIpc
        command: ["qs", "ipc", "call", "toggle-media", "toggle"]
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Music icon
        Text {
            text:             "󰎇"   // nf-md-music_note
            color:            GlobalState.matugenPrimary
            font.pixelSize:   15
            font.family:      "monospace"
            anchors.verticalCenter: parent.verticalCenter
        }

        // Scrolling title — artist text
        Item {
            id: mediaTextTrigger
            width:  120
            height: 20
            clip:   true
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: mediaText
                text:           MediaService.title.length > 0
                                    ? MediaService.title + " — " + MediaService.artist
                                    : MediaService.playerName
                color:          GlobalState.matugenOnSurface
                font.pixelSize: 12
                font.family:    "monospace"
                elide:          Text.NoElide
                x:              scrollAnim.running ? scrollAnim.from : 0

                // Scroll animation: slide left when text is wider than container
                NumberAnimation {
                    id:       scrollAnim
                    target:   mediaText
                    property: "x"
                    from:     0
                    to:       -(mediaText.implicitWidth - 120 + 8)
                    duration: Math.max(3000, (mediaText.implicitWidth - 120) * 30)
                    running:  mediaText.implicitWidth > 120
                    loops:    Animation.Infinite
                    onStopped: { mediaText.x = 0 }
                }
            }

            MouseArea {
                anchors.fill:  parent
                cursorShape:   Qt.PointingHandCursor
                onClicked: {
                    // Capture trigger geometry so MediaPane can anchor below this widget
                    var pos = mediaTextTrigger.mapToItem(null, 0, 0)
                    PopupAnchorService.setAnchor("media", pos.x, mediaTextTrigger.width, 40)
                    PopupStateService.toggleExclusive("media")
                    mediaPaneIpc.running = false
                    mediaPaneIpc.running = true
                }
            }
        }

        // Play/pause button
        Text {
            text:             MediaService.playbackStatus === "Playing" ? "󰏤" : "󰐊"
            color:            GlobalState.matugenOnSurface
            font.pixelSize:   15
            font.family:      "monospace"
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                ColorAnimation { duration: Appearance.popupFade }
            }

            MouseArea {
                anchors.fill:  parent
                cursorShape:   Qt.PointingHandCursor
                onClicked:     MediaService.playPause()
            }
        }
    }
}
