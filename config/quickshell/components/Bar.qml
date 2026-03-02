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
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../services"

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

    Process {
        id: wifiProcess
        command: ["alacritty", "-e", "nmtui"]
    }

    Process {
        id: btProcess
        command: ["alacritty", "-e", "bluetuith"]
    }

    Process {
        id: calProc
        command: ["quickshell", "ipc", "call", "toggle-calendar", "toggle"]
    }

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
            implicitHeight: 40
            color: "#1e1e2e"    // Catppuccin Mocha base

            exclusiveZone: 40

            // ------------------------------------------------------------------
            // Layout: [Workspaces] ——— [System Monitor] ——— [Tray | Icons | Clock]
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

                    Repeater {
                        model: Hyprland.workspaces.values

                        delegate: Rectangle {
                            id: wsPill
                            required property var modelData   // HyprlandWorkspace

                            width:  22
                            height: 22
                            radius: 4

                            color: modelData.focused ? "#cba6f7" : "#313244"

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text:  modelData.id > 0 ? modelData.id : modelData.name
                                color: wsPill.modelData.focused ? "#1e1e2e" : "#cdd6f4"
                                font.pixelSize: 11
                                font.bold: wsPill.modelData.focused
                            }

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

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    wsPill.modelData.activate();
                                }
                            }
                        }
                    }
                }

                // ── Left spacer ───────────────────────────────────────────────
                Item { Layout.fillWidth: true }

                // ── Middle section: System Monitor ────────────────────────────
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 16
                    
                    // CPU
                    Row {
                        spacing: 4
                        Text { text: "󰻠"; color: "#cba6f7"; font.family: "monospace"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Performance.cpuUsage.toFixed(1) + "%"; color: "#cdd6f4"; font.family: "monospace"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                    
                    // RAM
                    Row {
                        spacing: 4
                        Text { text: "󰍛"; color: "#89b4fa"; font.family: "monospace"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Performance.ramUsage.toFixed(1) + "%"; color: "#cdd6f4"; font.family: "monospace"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                    
                    // CPU Temp
                    Row {
                        spacing: 4
                        Text { text: "󰔏"; color: "#f38ba8"; font.family: "monospace"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Performance.cpuTemp.toFixed(1) + "°C"; color: "#cdd6f4"; font.family: "monospace"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                // ── Right spacer ──────────────────────────────────────────────
                Item { Layout.fillWidth: true }

                // ── Right section: sys tray & icons & clock ───────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 12
                    
                    // Static App Tray
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        // Wifi Icon
                        Text {
                            text: "󰖩" // nf-md-wifi (nerd font)
                            color: "#cdd6f4"
                            font.pixelSize: 16
                            font.family: "monospace"
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiProcess.running = true
                            }
                        }

                        // Bluetooth Icon
                        Text {
                            text: "󰂯" // nf-md-bluetooth (nerd font)
                            color: "#cdd6f4"
                            font.pixelSize: 16
                            font.family: "monospace"
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: btProcess.running = true
                            }
                        }
                    }
                    
                    // Theme Icon
                    Text {
                        text: "󰸉" // nf-md-wallpaper
                        color: "#cdd6f4"
                        font.pixelSize: 16
                        font.family: "monospace"
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: themeIpc.running = true
                        }
                        
                        Process {
                            id: themeIpc
                            command: ["quickshell", "ipc", "call", "toggle-theme", "toggle"]
                        }
                    }

                    // Notification Icon
                    Text {
                        text: "󰂚" // nf-md-bell
                        color: "#cdd6f4"
                        font.pixelSize: 16
                        font.family: "monospace"
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notifIpc.running = true
                        }
                        
                        Process {
                            id: notifIpc
                            command: ["quickshell", "ipc", "call", "toggle-notifs", "toggle"]
                        }
                    }

                    // Clock
                    Text {
                        id: clockLabel
                        text: barRoot.clockText
                        color: "#cdd6f4"    // Catppuccin Mocha text
                        font.pixelSize: 13
                        font.family: "monospace"
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calProc.running = true
                        }
                    }
                }
            }
        }
    }
}
