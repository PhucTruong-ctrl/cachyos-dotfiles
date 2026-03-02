// Power.qml
// Toggleable power-menu overlay for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-power toggle
// Keybind example (hyprland.conf):
//   bind = SUPER, End, exec, qs ipc call toggle-power toggle
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer with a dim backdrop.
//   - Six action buttons: Lock, Suspend, Logout, Reboot, Shutdown, Cancel.
//   - Clicking outside the card dismisses the menu.
//   - Pressing Escape dismisses the menu.
//   - Each action uses Process.exec() for a fire-and-forget subprocess.
//   - MUST NOT take focus when not visible (visible: false at start).

import Quickshell
import "../services"
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-power"
    // Invoke: qs ipc call toggle-power toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-power"

        function toggle(): void {
            console.log("[Power] IPC toggle called — visible was: " + powerWindow.visible);
            powerWindow.visible = !powerWindow.visible;
            console.log("[Power] visibility is now: " + powerWindow.visible);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Shared Process object for one-shot system commands
    // We call exec() on demand; no persistent process is kept.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: cmdProc
        // command and running are set dynamically via exec()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: run a command and close the overlay
    // ──────────────────────────────────────────────────────────────────────────
    function runCmd(args) {
        console.log("[Power] runCmd — executing: " + JSON.stringify(args));
        powerWindow.visible = false;
        cmdProc.exec(args);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: powerWindow

        // ── Hidden on startup — only IPC toggle makes it visible ──────────────
        visible: false

        // Keyboard focus so Escape works
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-power"

        // Span the full screen
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Transparent; the visual background is painted inside
        color: "transparent"

        // Do not push other windows aside
        exclusionMode: ExclusionMode.Ignore

        // ── Root Item: PanelWindow is not an Item, so Keys must go on a child ─
        Item {
            id: powerWindowRoot
            anchors.fill: parent
            focus: true

            // ── Global key handler for Escape ─────────────────────────────────
            Keys.onEscapePressed: {
                console.log("[Power] Escape pressed — closing power menu");
                powerWindow.visible = false;
            }

            // ── Dim backdrop (click outside → close) ──────────────────────────
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("[Power] backdrop clicked — closing power menu");
                    powerWindow.visible = false;
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0,0,0, 0.8)   // semi-transparent dark overlay
                }
            }

            // ──────────────────────────────────────────────────────────────────
            // Centered power-menu card
            // ──────────────────────────────────────────────────────────────────
            Rectangle {
                id: powerCard
                anchors.centerIn: parent
                width:  420
                height: implicitHeight + 48
                implicitHeight: cardLayout.implicitHeight
                radius: 18

                // Catppuccin Mocha palette (matches Bar.qml / Launcher.qml)
                color:        GlobalState.base   // base
                border.color: GlobalState.surface0   // surface0
                border.width: 1

                // Swallow backdrop clicks so they don't close the menu
                MouseArea {
                    anchors.fill: parent
                    onClicked: { /* swallow */ }
                }

                ColumnLayout {
                    id: cardLayout
                    anchors {
                        top:    parent.top
                        left:   parent.left
                        right:  parent.right
                        margins: 24
                    }
                    spacing: 16

                    // ── Header ────────────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: " Power"
                            color: GlobalState.matugenPrimary       // Catppuccin Mocha mauve
                            font.pixelSize: 18
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Choose an action"
                            color: GlobalState.overlay1       // overlay0
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // ── Divider ───────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color:  GlobalState.surface0   // surface0
                    }

                    // ── Action buttons grid (3 columns × 2 rows) ──────────────
                    GridLayout {
                        Layout.fillWidth: true
                        columns:    3
                        rowSpacing: 10
                        columnSpacing: 10

                        // Model: [ icon (Nerd Font), label, command args ]
                        // Buttons are instantiated via Repeater so adding/removing
                        // entries here requires zero other changes.
                        Repeater {
                            model: [
                                { icon: "󰌾", label: "Lock",     cmd: ["hyprlock"] },
                                { icon: "󰤄", label: "Suspend",  cmd: ["systemctl", "suspend"] },
                                { icon: "󰗼", label: "Logout",   cmd: ["hyprctl", "dispatch", "exit"] },
                                { icon: "󰜉", label: "Reboot",   cmd: ["systemctl", "reboot"] },
                                { icon: "󰐥", label: "Shutdown", cmd: ["systemctl", "poweroff"] },
                                { icon: "󰅗", label: "Cancel",   cmd: [] }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                height: 72
                                radius: 12

                                // Highlight colours per category
                                readonly property color accentColor: {
                                    if (modelData.label === "Cancel")   return GlobalState.overlay1  // overlay0 (neutral)
                                    if (modelData.label === "Lock")     return GlobalState.sky  // sky
                                    if (modelData.label === "Suspend")  return GlobalState.blue  // blue
                                    if (modelData.label === "Logout")   return GlobalState.peach  // peach
                                    if (modelData.label === "Reboot")   return GlobalState.warning  // yellow
                                    if (modelData.label === "Shutdown") return GlobalState.matugenError  // red
                                    return GlobalState.text
                                }

                                color: btnArea.containsMouse ? Qt.darker(accentColor, 4.5) : GlobalState.mantle

                                border.color: btnArea.containsMouse ? accentColor : GlobalState.surface0
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: Appearance.popupFade }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: Appearance.popupFade }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text:  modelData.icon
                                        color: parent.parent.accentColor
                                        font.pixelSize: 24
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text:  modelData.label
                                        color: btnArea.containsMouse
                                               ? GlobalState.text    // bright when hovered
                                               : GlobalState.subtext0    // subtext1 otherwise
                                        font.pixelSize: 12
                                        font.bold: btnArea.containsMouse
                                        Layout.alignment: Qt.AlignHCenter

                                        Behavior on color {
                                            ColorAnimation { duration: Appearance.popupFade }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: btnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape:  Qt.PointingHandCursor

                                    onClicked: {
                                        if (modelData.label === "Cancel") {
                                            console.log("[Power] button clicked: Cancel — closing menu");
                                            powerWindow.visible = false;
                                        } else {
                                            console.log("[Power] button clicked: " + modelData.label +
                                                " — executing: " + JSON.stringify(modelData.cmd));
                                            root.runCmd(modelData.cmd);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Spacer at the bottom of the card
                    Item { height: 8 }
                }
            }
        } // end Item powerWindowRoot
    }
}
