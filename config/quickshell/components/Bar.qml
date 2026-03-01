// Bar.qml
// Minimal top-panel status bar for Quickshell.
// Renders one PanelWindow per screen so the bar spans every monitor.
// Contains:
//   - Clock: driven by Quickshell's built-in SystemClock (seconds precision)
//   - Workspace indicator: live Repeater bound to Hyprland.workspaces.values
//     Each pill is clickable — calls workspace.activate() to switch.
//     The focused workspace is highlighted in Catppuccin Mocha mauve.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
    id: barRoot

    // ---------------------------------------------------------------------------
    // Clock string — single SystemClock instance shared across all bar windows
    // ---------------------------------------------------------------------------
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property string clockText: Qt.formatDateTime(clock.date, "hh:mm:ss  ddd d MMM")

    // ---------------------------------------------------------------------------
    // One PanelWindow per monitor (handles hotplug correctly via Variants)
    // ---------------------------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            // Quickshell injects the ShellScreen for this instance
            required property var modelData
            screen: modelData

            // Anchor to the full top edge of the screen
            anchors {
                top:   true
                left:  true
                right: true
            }

            // Bar geometry & background
            // NOTE: implicitHeight is the correct property (QsWindow.height is
            // deprecated).  The compositor sizes the surface from implicitHeight.
            implicitHeight: 40
            color: "#1e1e2e"    // Catppuccin Mocha base

            // Reserve exclusive space so Hyprland subtracts exactly 40 px from
            // the top of the usable area on every monitor, preventing tiled
            // windows from sliding under the bar.
            //
            // Why exclusiveZone and NOT exclusionMode?
            //   - exclusionMode: ExclusionMode.Normal tells QS to *auto-derive*
            //     the zone from the committed surface size, which can race on
            //     startup or break with the deprecated `height` property.
            //   - exclusiveZone: 40 sets the wlr-layer-shell exclusiveZone
            //     directly and unconditionally.  Setting this also implicitly
            //     sets exclusionMode to Normal (per QS 0.2 docs), so there is
            //     no conflict.  This is the only reliable path on Hyprland.
            exclusiveZone: 40

            // ------------------------------------------------------------------
            // Layout: [Workspaces] ——————————— [Clock]
            // ------------------------------------------------------------------
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin:  12
                anchors.rightMargin: 12
                spacing: 0

                // ── Left section: live workspace pills ────────────────────────
                Row {
                    id: workspacesRow
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    // Hyprland.workspaces is an ObjectModel<HyprlandWorkspace>.
                    // .values exposes the backing JS array so a standard Repeater
                    // can iterate it.  The model is reactive: Quickshell updates
                    // it whenever workspaces are added, removed, or focused.
                    Repeater {
                        model: Hyprland.workspaces.values

                        delegate: Rectangle {
                            id: wsPill
                            required property var modelData   // HyprlandWorkspace

                            width:  22
                            height: 22
                            radius: 4

                            // Focused workspace → mauve pill; others → surface0
                            color: modelData.focused ? "#cba6f7" : "#313244"

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Text {
                                anchors.centerIn: parent
                                // Prefer the numeric id; fall back to the name
                                text:  modelData.id > 0 ? modelData.id : modelData.name
                                color: wsPill.modelData.focused ? "#1e1e2e" : "#cdd6f4"
                                font.pixelSize: 11
                                font.bold: wsPill.modelData.focused
                            }

                            // Urgent indicator — tiny red dot in the top-right corner
                            Rectangle {
                                visible: wsPill.modelData.urgent
                                width:  6
                                height: 6
                                radius: 3
                                color:  "#f38ba8"   // Catppuccin Mocha red
                                anchors {
                                    top:        parent.top
                                    right:      parent.right
                                    topMargin:  2
                                    rightMargin: 2
                                }
                            }

                            // Click → switch to this workspace
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    console.log("[Bar] workspace pill clicked: id=" +
                                        wsPill.modelData.id + " name=" +
                                        wsPill.modelData.name + " focused=" +
                                        wsPill.modelData.focused);
                                    wsPill.modelData.activate();
                                }
                            }
                        }
                    }
                }

                // ── Center spacer ─────────────────────────────────────────────
                Item { Layout.fillWidth: true }

                // ── Right section: clock ───────────────────────────────────────
                Text {
                    id: clockLabel
                    Layout.alignment: Qt.AlignVCenter
                    text:  barRoot.clockText
                    color: "#cdd6f4"    // Catppuccin Mocha text
                    font.pixelSize: 13
                    font.family:    "monospace"
                }
            }
        }
    }
}
