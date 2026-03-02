// Launcher.qml
// Toggleable application launcher overlay for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-launcher toggle
// Keybind example (hyprland.conf):
//   bind = SUPER, Space, exec, qs ipc call toggle-launcher toggle
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer with a dim backdrop.
//   - Clicking outside the launcher box dismisses it.
//   - Pressing Escape dismisses it.
//   - DesktopEntries provides live .desktop file enumeration (no subprocess).
//   - ScriptModel filters by name / genericName / comment as the user types.
//   - Arrow keys + Enter/Return navigate and launch.
//   - MUST NOT take focus when not explicitly toggled (visible: false at start).

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-launcher"
    // Invoke: qs ipc call toggle-launcher toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-launcher"

        function toggle(): void {
            console.log("[Launcher] IPC toggle called — visible was: " + launcherWindow.visible);
            launcherWindow.visible = !launcherWindow.visible;
            if (launcherWindow.visible) {
                console.log("[Launcher] opening — resetting search and focusing input");
                searchInput.text = "";
                root.selectedIndex = 0;
                searchInput.forceActiveFocus();
            } else {
                console.log("[Launcher] closing");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────────────────────────────────
    property int selectedIndex: 0
    property bool usingKeyboard: false   // true while navigating via arrow keys

    // ──────────────────────────────────────────────────────────────────────────
    // Filtered application list
    // ScriptModel re-evaluates reactively whenever `values` dependencies change.
    // ──────────────────────────────────────────────────────────────────────────
    ScriptModel {
        id: filteredApps
        // `objectProp` is used as the unique key so ListView delegates can be
        // matched to their model items without relying on index alone.
        objectProp: "id"

        values: {
            const all = [...DesktopEntries.applications.values];
            const q = searchInput.text.trim().toLowerCase();

            // No query → return full sorted list
            if (q === "") {
                return all.sort((a, b) => a.name.localeCompare(b.name));
            }

            // Filter: name, genericName, or comment contains the query
            return all.filter(d =>
                (d.name    && d.name.toLowerCase().includes(q)) ||
                (d.genericName && d.genericName.toLowerCase().includes(q)) ||
                (d.comment && d.comment.toLowerCase().includes(q))
            ).sort((a, b) => {
                // Entries whose name *starts* with the query sort first
                const an = a.name.toLowerCase();
                const bn = b.name.toLowerCase();
                const aStart = an.startsWith(q);
                const bStart = bn.startsWith(q);
                if (aStart && !bStart) return -1;
                if (!aStart && bStart) return 1;
                return an.localeCompare(bn);
            });
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: launch an app and close the launcher
    // ──────────────────────────────────────────────────────────────────────────
    function launchApp(entry) {
        console.log("[Launcher] launching app: name=" + (entry.name ?? "(unknown)") +
            " exec=" + (entry.exec ?? "(unknown)"));
        entry.execute();
        launcherWindow.visible = false;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // PanelWindow + Overlay layer gives us a layer-shell surface that sits above
    // all normal windows without becoming a floating top-level (which would show
    // up in the taskbar / alt-tab).
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: launcherWindow

        // ── Hidden on startup — only IPC toggle makes it visible ──────────────
        visible: false

        // Allow the launcher to receive keyboard input when shown
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-launcher"

        // Span the full screen so the dim backdrop covers everything
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Transparent – the visual background is painted inside
        color: "transparent"

        // Do not push other windows aside
        exclusionMode: ExclusionMode.Ignore

        // ── Dim backdrop (click outside → close) ──────────────────────────────
        MouseArea {
            anchors.fill: parent
            // Only close when clicking the backdrop, not the launcher box itself
            onClicked: {
                console.log("[Launcher] backdrop clicked — closing launcher");
                launcherWindow.visible = false;
            }

            Rectangle {
                anchors.fill: parent
                color: "#aa000000"   // semi-transparent black overlay
            }
        }

        // ── Centered launcher card ─────────────────────────────────────────────
        Rectangle {
            id: launcherBox
            anchors.centerIn: parent
            width:  580
            height: 500
            radius: 14

            // Catppuccin Mocha palette (matches Bar.qml)
            color:        "#1e1e2e"   // base
            border.color: "#313244"   // surface0
            border.width: 1

            // Prevent backdrop click from propagating through the card
            MouseArea {
                anchors.fill: parent
                onClicked: { /* swallow — do nothing */ }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                // ── Header ────────────────────────────────────────────────────
                Text {
                    text: " App Launcher"
                    color: "#cba6f7"       // Catppuccin Mocha mauve
                    font.pixelSize: 15
                    font.bold: true
                }

                // ── Search box ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: "#313244"      // surface0
                    border.color: searchInput.activeFocus ? "#cba6f7" : "#45475a"
                    border.width: 1

                    // Animate border color on focus
                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin:  14
                        anchors.rightMargin: 14
                        spacing: 10

                        // Search icon
                        Text {
                            text: ""          // Nerd Font search glyph
                            color: "#6c7086"
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Input field
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color:            "#cdd6f4"   // text
                            font.pixelSize:   15
                            clip:             true

                            // Placeholder
                            Text {
                                anchors.fill:       parent
                                text:               "Type to search applications…"
                                color:              "#6c7086"   // overlay0
                                font:               parent.font
                                visible:            !parent.text && !parent.activeFocus
                                verticalAlignment:  Text.AlignVCenter
                            }

                            // Reset selection on every keystroke
                            onTextChanged: root.selectedIndex = 0

                            // ── Keyboard navigation ───────────────────────────
                            Keys.onEscapePressed: {
                                console.log("[Launcher] Escape pressed — closing launcher");
                                launcherWindow.visible = false;
                            }

                            Keys.onDownPressed: {
                                root.usingKeyboard = true;
                                root.selectedIndex = Math.min(
                                    root.selectedIndex + 1,
                                    resultsList.count - 1
                                );
                                console.log("[Launcher] key Down — selectedIndex=" + root.selectedIndex);
                                resultsList.positionViewAtIndex(
                                    root.selectedIndex, ListView.Contain
                                );
                            }

                            Keys.onUpPressed: {
                                root.usingKeyboard = true;
                                root.selectedIndex = Math.max(
                                    root.selectedIndex - 1, 0
                                );
                                console.log("[Launcher] key Up — selectedIndex=" + root.selectedIndex);
                                resultsList.positionViewAtIndex(
                                    root.selectedIndex, ListView.Contain
                                );
                            }

                            Keys.onTabPressed: {
                                root.usingKeyboard = true;
                                root.selectedIndex = Math.min(
                                    root.selectedIndex + 1,
                                    resultsList.count - 1
                                );
                                resultsList.positionViewAtIndex(
                                    root.selectedIndex, ListView.Contain
                                );
                            }

                            Keys.onReturnPressed: {
                                if (resultsList.count > 0) {
                                    const entry =
                                        filteredApps.values[root.selectedIndex];
                                    if (entry) root.launchApp(entry);
                                }
                            }

                            Keys.onEnterPressed: {
                                if (resultsList.count > 0) {
                                    const entry =
                                        filteredApps.values[root.selectedIndex];
                                    if (entry) root.launchApp(entry);
                                }
                            }
                        }
                    }
                }

                // ── Result count hint ─────────────────────────────────────────
                Text {
                    text: resultsList.count + " result" +
                          (resultsList.count !== 1 ? "s" : "")
                    color:          "#6c7086"   // overlay0
                    font.pixelSize: 11
                }

                // ── Results list ──────────────────────────────────────────────
                ListView {
                    id: resultsList
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    model:             filteredApps
                    clip:              true
                    spacing:           2
                    boundsBehavior:    Flickable.StopAtBounds
                    currentIndex:      root.selectedIndex
                    highlightMoveDuration: 120
                    highlightMoveVelocity: -1

                    // Selection highlight bar
                    highlight: Rectangle {
                        radius: 8
                        color:  "#313244"   // surface0

                        // Left accent stripe
                        Rectangle {
                            width:  3
                            height: 22
                            radius: 2
                            color:  "#cba6f7"   // mauve
                            anchors.left:            parent.left
                            anchors.leftMargin:      3
                            anchors.verticalCenter:  parent.verticalCenter
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index

                        width:  resultsList.width
                        height: 46
                        radius: 8
                        color:  hoverArea.containsMouse &&
                                root.selectedIndex !== index
                                ? "#181825"   // mantle — subtle hover tint
                                : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        RowLayout {
                            anchors.fill:        parent
                            anchors.leftMargin:  12
                            anchors.rightMargin: 12
                            spacing: 12

                            // ── App icon ─────────────────────────────────────
                            Item {
                                width:  28
                                height: 28
                                Layout.alignment: Qt.AlignVCenter

                                IconImage {
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(
                                        delegateRoot.modelData.icon ?? "", true
                                    )
                                    visible: (delegateRoot.modelData.icon ?? "") !== ""
                                }

                                // Fallback glyph when no icon is available
                                Text {
                                    anchors.centerIn: parent
                                    text:             ""   // Nerd Font terminal glyph
                                    color:            "#cba6f7"
                                    font.pixelSize:   20
                                    visible: (delegateRoot.modelData.icon ?? "") === ""
                                }
                            }

                            // ── Text info ────────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth:  true
                                Layout.alignment:  Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text:  delegateRoot.modelData.name ?? ""
                                    color: root.selectedIndex === delegateRoot.index
                                           ? "#cdd6f4"   // text (bright when selected)
                                           : "#a6adc8"   // subtext1
                                    font.pixelSize: 13
                                    font.bold: root.selectedIndex === delegateRoot.index
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: delegateRoot.modelData.genericName ??
                                          delegateRoot.modelData.comment ?? ""
                                    color:          "#6c7086"   // overlay0
                                    font.pixelSize: 11
                                    elide:          Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill:  parent
                            hoverEnabled:  true
                            cursorShape:   Qt.PointingHandCursor
                            onClicked: {
                                console.log("[Launcher] app item clicked: name=" +
                                    (delegateRoot.modelData.name ?? "(unknown)"));
                                root.launchApp(delegateRoot.modelData);
                            }
                            onPositionChanged: {
                                // Mouse moved — switch back to mouse-driven selection
                                root.usingKeyboard = false;
                                root.selectedIndex = delegateRoot.index;
                            }
                        }
                    }

                    // ── Empty state ───────────────────────────────────────────
                    Text {
                        anchors.centerIn: parent
                        text:  "No applications found"
                        color: "#6c7086"
                        font.pixelSize: 14
                        visible: resultsList.count === 0 && searchInput.text !== ""
                    }
                }

                // ── Keyboard shortcut hints ───────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: [
                            { key: "↑↓",    label: "navigate" },
                            { key: "⏎",     label: "launch"   },
                            { key: "Esc",   label: "close"    }
                        ]

                        Row {
                            required property var modelData
                            spacing: 4

                            Rectangle {
                                width:  keyLabel.implicitWidth + 8
                                height: 18
                                radius: 4
                                color:  "#313244"

                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text:             modelData.key
                                    color:            "#6c7086"
                                    font.pixelSize:   10
                                }
                            }

                            Text {
                                text:           modelData.label
                                color:          "#6c7086"
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
