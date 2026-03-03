// MediaWidget.qml — End4-style compact MPRIS media widget for the Bar
//
// Always visible on the bar (never hidden, even without an active player).
//
// States:
//   No player active → greyed music icon + "No media" label
//   Player active (paused) → music icon + scrolling title/artist + play button
//   Player active (playing) → mini visualizer strip + scrolling title/artist + pause button
//
// Clicking the title/artist area opens MediaPane via PopupStateService ("media" id),
// anchored directly below this widget via PopupAnchorService.
// Play/pause button toggles playback directly via MediaService.
//
// Colors: all from GlobalState
// Animations: all durations/curves from Appearance

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../services"

Item {
    id: root

    // Always on the bar — width adapts between "no media" and "active" states
    // Extra padding (16 vs 8) gives the hover pill comfortable breathing room
    width:  contentRow.implicitWidth + 16
    height: 40

    // ── Hover pill background ─────────────────────────────────────────────────
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width:  parent.width
        height: 28
        radius: Appearance.barItemRadius
        color:  mediaWidgetHover.containsMouse ? GlobalState.matugenSurface : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.barHoverDuration } }
    }

    HoverHandler { id: mediaWidgetHover }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        // ── No-player fallback: greyed icon + "No media" ──────────────────────
        Row {
            id: noMediaRow
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            // Smooth cross-fade: fade out then hide; show then fade in
            state: MediaService.hasPlayer ? "hidden" : "shown"
            states: [
                State {
                    name: "shown"
                    PropertyChanges { target: noMediaRow; opacity: 1.0; visible: true }
                },
                State {
                    name: "hidden"
                    PropertyChanges { target: noMediaRow; opacity: 0.0; visible: false }
                }
            ]
            transitions: [
                Transition {
                    from: "shown"; to: "hidden"
                    SequentialAnimation {
                        NumberAnimation { property: "opacity"; duration: Appearance.mediaReveal; easing.type: Easing.OutQuad }
                        PropertyAction  { property: "visible"; value: false }
                    }
                },
                Transition {
                    from: "hidden"; to: "shown"
                    SequentialAnimation {
                        PropertyAction  { property: "visible"; value: true }
                        NumberAnimation { property: "opacity"; duration: Appearance.mediaReveal; easing.type: Easing.OutQuad }
                    }
                }
            ]

            Text {
                text:           "󰎇"   // nf-md-music_note
                color:          GlobalState.overlay1
                font.pixelSize: 13
                font.family:    "monospace"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text:           "No media"
                color:          GlobalState.overlay1
                font.pixelSize: 12
                font.family:    "monospace"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Active player state ───────────────────────────────────────────────
        Row {
            id: activeRow
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            // Smooth cross-fade: show then fade in; fade out then hide
            state: MediaService.hasPlayer ? "shown" : "hidden"
            states: [
                State {
                    name: "shown"
                    PropertyChanges { target: activeRow; opacity: 1.0; visible: true }
                },
                State {
                    name: "hidden"
                    PropertyChanges { target: activeRow; opacity: 0.0; visible: false }
                }
            ]
            transitions: [
                Transition {
                    from: "hidden"; to: "shown"
                    SequentialAnimation {
                        PropertyAction  { property: "visible"; value: true }
                        NumberAnimation { property: "opacity"; duration: Appearance.mediaReveal; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    from: "shown"; to: "hidden"
                    SequentialAnimation {
                        NumberAnimation { property: "opacity"; duration: Appearance.mediaReveal; easing.type: Easing.OutQuad }
                        PropertyAction  { property: "visible"; value: false }
                    }
                }
            ]

            // Mini visualizer strip: 8 bars mapped from CavaService (shown when Playing)
            Row {
                id: visualizerStrip
                visible: MediaService.playbackStatus === "Playing"
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    // Use every 2nd cava bar (stride=2) to sample 8 bars from 20
                    model: 8

                    delegate: Item {
                        width:  3
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            readonly property real barVal: {
                                const idx = index * 2;
                                return (CavaService.bars && CavaService.bars.length > idx)
                                    ? CavaService.bars[idx]
                                    : 0.0;
                            }

                            width:          parent.width
                            height:         Math.max(2, parent.height * barVal)
                            anchors.bottom: parent.bottom
                            radius:         1
                            color:          GlobalState.matugenPrimary

                            Behavior on height {
                                NumberAnimation {
                                    duration:    80
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }
            }

            // Music icon — shown when paused (replaces visualizer)
            Text {
                visible:        MediaService.playbackStatus !== "Playing"
                text:           "󰎇"   // nf-md-music_note
                color:          GlobalState.matugenPrimary
                font.pixelSize: 13
                font.family:    "monospace"
                anchors.verticalCenter: parent.verticalCenter
            }

            // Scrolling title — artist text; click opens MediaPane
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
                    elide:          Text.ElideNone
                    x:              scrollAnim.running ? scrollAnim.from : 0

                    // Scroll animation: slide left when text overflows container
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
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        // Capture trigger geometry so MediaPane anchors below this widget
                        var pos = mediaTextTrigger.mapToItem(null, 0, 0)
                        PopupAnchorService.setAnchor("media", pos.x, mediaTextTrigger.width, 40)
                        PopupStateService.toggleExclusive("media")
                    }
                }
            }

            // Play/pause toggle button
            Text {
                text:           MediaService.playbackStatus === "Playing" ? "󰏤" : "󰐊"
                color:          GlobalState.matugenOnSurface
                font.pixelSize: 15
                font.family:    "monospace"
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: Appearance.popupFade }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    MediaService.playPause()
                }
            }
        }
    }
}
