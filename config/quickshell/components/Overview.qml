// Overview.qml
// Fullscreen window-switcher overlay for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-overview toggle
// Keybind (hyprland.conf):
//   bind = SUPER, Tab, exec, qs ipc call toggle-overview toggle
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer, no exclusion zone.
//   - Horizontal row of workspace columns, each showing window cards.
//   - Window cards: app class icon + truncated title, proportionally sized.
//   - Click a card  → focus window, close overview.
//   - Click empty workspace area → switch to workspace, close overview.
//   - Search bar filters by title/class.
//   - Escape or backdrop click → close.
//   - Refreshes window and workspace list every time it opens.
//   - All colors from GlobalState; all animations from Appearance.

import Quickshell
import "../services"
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-overview"
    // Invoke: qs ipc call toggle-overview toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-overview"

        function toggle(): void {
            console.log("[Overview] IPC toggle called — visible was: " + overviewWindow.visible);
            overviewWindow.visible = !overviewWindow.visible;
            if (overviewWindow.visible) {
                console.log("[Overview] opening — refreshing window list");
                searchInput.text = "";
                HyprlandService.fetchWorkspaces();
                HyprlandService.fetchClients();
                searchInput.forceActiveFocus();
            } else {
                console.log("[Overview] closing");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: close overview
    // ──────────────────────────────────────────────────────────────────────────
    function close() {
        overviewWindow.visible = false;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: filter clients for a given workspaceId by current search query
    // Returns a plain JS array of client objects.
    // ──────────────────────────────────────────────────────────────────────────
    function clientsForWorkspace(wsId) {
        const q = searchInput.text.trim().toLowerCase();
        const result = [];
        const count = HyprlandService.clientModel.count;
        for (let i = 0; i < count; i++) {
            const c = HyprlandService.clientModel.get(i);
            if (c.workspaceId !== wsId) continue;
            if (q !== "" &&
                !c.title.toLowerCase().includes(q) &&
                !c.klass.toLowerCase().includes(q)) {
                continue;
            }
            result.push({
                address:       c.address,
                klass:         c.klass,
                title:         c.title,
                workspaceId:   c.workspaceId,
                workspaceName: c.workspaceName,
                sizeW:         c.sizeW,
                sizeH:         c.sizeH,
                icon:          c.icon
            });
        }
        return result;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: overviewWindow

        // Hidden on startup — only IPC toggle makes it visible
        visible: false

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-overview"

        // Span the full screen
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // ── Root item for key handling ────────────────────────────────────────
        Item {
            id: overviewRoot
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: {
                console.log("[Overview] Escape — closing");
                root.close();
            }

            // ── Dim backdrop ──────────────────────────────────────────────────
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("[Overview] backdrop clicked — closing");
                    root.close();
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.75)
                }
            }

            // ── Main panel ────────────────────────────────────────────────────
            // Stop click-through from backdrop
            MouseArea {
                id: panelArea
                anchors.centerIn:  parent
                width:  Math.min(parent.width  - 80, 1400)
                height: Math.min(parent.height - 80, 800)
                onClicked: { /* swallow */ }

                Rectangle {
                    id: overviewPanel
                    anchors.fill: parent
                    radius: Appearance.panelRadius
                    color:  Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
                    border.color: GlobalState.surface0
                    border.width: 1

                    ColumnLayout {
                        anchors.fill:    parent
                        anchors.margins: 20
                        spacing: 14

                        // ── Header row: title + search bar ────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Panel title
                            Text {
                                text:           " Overview"
                                color:          GlobalState.matugenPrimary
                                font.pixelSize: 18
                                font.bold:      true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            // Search box
                            Rectangle {
                                width:  280
                                height: 36
                                radius: 8
                                color:  GlobalState.surface0
                                border.color: searchInput.activeFocus
                                              ? GlobalState.matugenPrimary
                                              : GlobalState.surface1
                                border.width: 1

                                Behavior on border.color {
                                    ColorAnimation { duration: Appearance.popupFade }
                                }

                                RowLayout {
                                    anchors.fill:          parent
                                    anchors.leftMargin:    10
                                    anchors.rightMargin:   10
                                    spacing: 8

                                    Text {
                                        text:             ""   // Nerd Font search
                                        color:            GlobalState.overlay1
                                        font.pixelSize:   14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    TextInput {
                                        id: searchInput
                                        Layout.fillWidth:  true
                                        Layout.alignment:  Qt.AlignVCenter
                                        color:             GlobalState.text
                                        font.pixelSize:    13
                                        clip:              true

                                        Text {
                                            anchors.fill:      parent
                                            text:              "Filter windows…"
                                            color:             GlobalState.overlay1
                                            font:              parent.font
                                            visible:           !parent.text && !parent.activeFocus
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Keys.onEscapePressed: root.close()
                                    }
                                }
                            }

                            // Close hint
                            Text {
                                text:             "Esc to close"
                                color:            GlobalState.overlay1
                                font.pixelSize:   11
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // ── Divider ───────────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color:  GlobalState.surface0
                        }

                        // ── Workspace columns ─────────────────────────────────
                        // ScrollView so it can handle many workspaces
                        ScrollView {
                            Layout.fillWidth:  true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                            ScrollBar.vertical.policy:   ScrollBar.AlwaysOff

                            // Empty state
                            Text {
                                anchors.centerIn: parent
                                text:    "No open windows"
                                color:   GlobalState.overlay1
                                font.pixelSize: 16
                                visible: HyprlandService.workspaceModel.count === 0
                            }

                            Row {
                                spacing: 14
                                height: parent.height

                                Repeater {
                                    model: HyprlandService.workspaceModel

                                    // ── Workspace column ──────────────────────
                                    Rectangle {
                                        required property var  modelData
                                        required property int  index

                                        // workspaceClients is refreshed when search changes
                                        // or model changes.
                                        property var workspaceClients: root.clientsForWorkspace(modelData.id)

                                        // Connections to refresh clients when model or search changes
                                        Connections {
                                            target: HyprlandService.clientModel
                                            function onCountChanged() {
                                                workspaceClients = root.clientsForWorkspace(modelData.id);
                                            }
                                        }
                                        Connections {
                                            target: searchInput
                                            function onTextChanged() {
                                                workspaceClients = root.clientsForWorkspace(modelData.id);
                                            }
                                        }

                                        width:  220
                                        height: parent.height
                                        radius: 10
                                        color:  wsHoverArea.containsMouse && workspaceClients.length === 0
                                                ? Qt.rgba(GlobalState.surface0.r, GlobalState.surface0.g, GlobalState.surface0.b, 0.4)
                                                : Qt.rgba(GlobalState.mantle.r,   GlobalState.mantle.g,   GlobalState.mantle.b,   0.6)
                                        border.color: GlobalState.surface1
                                        border.width: 1

                                        Behavior on color {
                                            ColorAnimation { duration: Appearance.popupFade }
                                        }

                                        ColumnLayout {
                                            anchors.fill:    parent
                                            anchors.margins: 10
                                            spacing: 8

                                            // ── Workspace header ──────────────
                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text:             " " + modelData.name
                                                    color:            GlobalState.matugenPrimary
                                                    font.pixelSize:   13
                                                    font.bold:        true
                                                    elide:            Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text:           workspaceClients.length + " win"
                                                    color:          GlobalState.overlay1
                                                    font.pixelSize: 10
                                                }
                                            }

                                            // ── Divider under header ──────────
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color:  GlobalState.surface1
                                            }

                                            // ── Window cards ─────────────────
                                            // Use a Flickable so cards can scroll vertically
                                            Flickable {
                                                Layout.fillWidth:  true
                                                Layout.fillHeight: true
                                                contentHeight:     cardsColumn.implicitHeight
                                                clip:              true
                                                boundsBehavior:    Flickable.StopAtBounds

                                                Column {
                                                    id: cardsColumn
                                                    width:   parent.width
                                                    spacing: 6

                                                    Repeater {
                                                        model: workspaceClients

                                                        // ── Window card ───────
                                                        Rectangle {
                                                            required property var modelData
                                                            required property int index

                                                            width:  parent.width
                                                            // Proportional height: clamp to 60–100px
                                                            height: {
                                                                const ratio = (modelData.sizeH > 0 && modelData.sizeW > 0)
                                                                              ? modelData.sizeH / modelData.sizeW
                                                                              : 0.5;
                                                                return Math.max(60, Math.min(100, Math.round(200 * ratio)));
                                                            }
                                                            radius: 8

                                                            color:  cardArea.containsMouse
                                                                    ? GlobalState.surface1
                                                                    : GlobalState.surface0
                                                            border.color: cardArea.containsMouse
                                                                          ? GlobalState.matugenPrimary
                                                                          : "transparent"
                                                            border.width: 1

                                                            Behavior on color {
                                                                ColorAnimation { duration: Appearance.popupFade }
                                                            }
                                                            Behavior on border.color {
                                                                ColorAnimation { duration: Appearance.popupFade }
                                                            }

                                                            RowLayout {
                                                                anchors.fill:          parent
                                                                anchors.leftMargin:    8
                                                                anchors.rightMargin:   8
                                                                anchors.topMargin:     6
                                                                anchors.bottomMargin:  6
                                                                spacing: 8

                                                                // App icon
                                                                Item {
                                                                    width:  28
                                                                    height: 28
                                                                    Layout.alignment: Qt.AlignVCenter

                                                                    IconImage {
                                                                        anchors.fill: parent
                                                                        source: Quickshell.iconPath(modelData.icon, true)
                                                                        visible: modelData.icon !== ""
                                                                    }

                                                                    // Fallback glyph
                                                                    Text {
                                                                        anchors.centerIn: parent
                                                                        text:             ""   // Nerd Font window glyph
                                                                        color:            GlobalState.matugenPrimary
                                                                        font.pixelSize:   20
                                                                        visible: modelData.icon === ""
                                                                    }
                                                                }

                                                                // Title + class
                                                                ColumnLayout {
                                                                    Layout.fillWidth: true
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    spacing: 2

                                                                    Text {
                                                                        text:           modelData.title
                                                                        color:          GlobalState.text
                                                                        font.pixelSize: 12
                                                                        font.bold:      cardArea.containsMouse
                                                                        elide:          Text.ElideRight
                                                                        Layout.fillWidth: true

                                                                        Behavior on color {
                                                                            ColorAnimation { duration: Appearance.popupFade }
                                                                        }
                                                                    }

                                                                    Text {
                                                                        text:           modelData.klass
                                                                        color:          GlobalState.overlay1
                                                                        font.pixelSize: 10
                                                                        elide:          Text.ElideRight
                                                                        Layout.fillWidth: true
                                                                    }
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: cardArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape:  Qt.PointingHandCursor

                                                                onClicked: {
                                                                    console.log("[Overview] window card clicked: " + modelData.address);
                                                                    HyprlandService.focusWindow(modelData.address);
                                                                    root.close();
                                                                }
                                                            }
                                                        }
                                                    } // Repeater window cards
                                                } // Column cardsColumn
                                            } // Flickable
                                        } // ColumnLayout (workspace content)

                                        // Click on empty workspace area → switch workspace
                                        MouseArea {
                                            id: wsHoverArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            // Only activate when no window cards are present
                                            enabled: workspaceClients.length === 0
                                            cursorShape: workspaceClients.length === 0
                                                         ? Qt.PointingHandCursor
                                                         : Qt.ArrowCursor

                                            onClicked: {
                                                if (workspaceClients.length === 0) {
                                                    console.log("[Overview] empty workspace clicked: " + modelData.id);
                                                    HyprlandService.moveToWorkspace(modelData.id);
                                                    root.close();
                                                }
                                            }
                                        }
                                    } // Rectangle workspace column
                                } // Repeater workspaces
                            } // Row
                        } // ScrollView

                        // ── Bottom hint bar ───────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: [
                                    { key: "Click",  label: "focus window"    },
                                    { key: "Empty",  label: "switch workspace" },
                                    { key: "Esc",    label: "close"           }
                                ]

                                Row {
                                    required property var modelData
                                    spacing: 4

                                    Rectangle {
                                        width:  hintKeyLabel.implicitWidth + 8
                                        height: 18
                                        radius: 4
                                        color:  GlobalState.surface0

                                        Text {
                                            id: hintKeyLabel
                                            anchors.centerIn: parent
                                            text:             modelData.key
                                            color:            GlobalState.overlay1
                                            font.pixelSize:   10
                                        }
                                    }

                                    Text {
                                        text:           modelData.label
                                        color:          GlobalState.overlay1
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    } // ColumnLayout main panel
                } // Rectangle overviewPanel
            } // MouseArea panelArea
        } // Item overviewRoot
    } // PanelWindow
}
