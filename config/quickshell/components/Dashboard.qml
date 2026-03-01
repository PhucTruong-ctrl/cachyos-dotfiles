// Dashboard.qml — Quickshell Dashboard overlay
// 
// Large panel anchored to the right side of the screen containing
// the Notification Center and Performance metrics.
//
// Triggered via: qs ipc call toggle-dashboard toggle

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

PanelWindow {
    id: root

    // ------------------------------------------------------------------
    // Panel Window Settings
    // ------------------------------------------------------------------
    // Position on the right side of the screen
    anchors {
        top: true
        bottom: true
        right: true
    }

    width: 380

    // Set to overlay layer
    WlrLayerShell.layer: WlrLayer.Overlay
    
    // Ensure search fields work (if any) but doesn't hijack the compositor when hidden
    WlrLayerShell.keyboardFocus: KeyboardFocus.OnDemand

    color: "transparent"

    // Default hidden state
    visible: false

    // ------------------------------------------------------------------
    // IPC Handler (qs ipc call toggle-dashboard toggle)
    // ------------------------------------------------------------------
    IpcHandler {
        target: "toggle-dashboard"
        onMessage: (msg) => {
            if (msg === "toggle") {
                root.visible = !root.visible
            } else if (msg === "show") {
                root.visible = true
            } else if (msg === "hide") {
                root.visible = false
            } else {
                console.warn("Dashboard module unhandled IPC target:", target, "message:", msg)
            }
        }
    }

    // Auto-hide when focus is lost clicking outside (assuming it doesn't break things)
    onActiveFocusChanged: {
        if (!activeFocus && root.visible) {
            root.visible = false
        }
    }

    // Main layout
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "#1e1e2e" // Catppuccin Mocha Base
        radius: 12
        border.color: "#89b4fa" // Catppuccin Mocha Blue
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // Performance Header
            Text {
                text: "System Monitor"
                font.pixelSize: 18
                font.bold: true
                color: "#cdd6f4" // Catppuccin Mocha Text
                Layout.alignment: Qt.AlignHCenter
            }

            // Performance Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // CPU
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#313244" // Surface0
                    radius: 8
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        Text {
                            text: "CPU"
                            color: "#a6adc8" // Subtext0
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            // Link to Performance.qml service CPU usage
                            text: Performance.cpuUsage.toFixed(1) + "%"
                            color: "#cdd6f4"
                            font.pixelSize: 20
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // RAM
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#313244" // Surface0
                    radius: 8
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        Text {
                            text: "RAM"
                            color: "#a6adc8" // Subtext0
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            // Link to Performance.qml service memory usage
                            text: Performance.ramUsage.toFixed(1) + "%"
                            color: "#cdd6f4"
                            font.pixelSize: 20
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // CPU Temp (Bonus)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "#313244" // Surface0
                radius: 8

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text {
                        text: "TEMP"
                        color: "#a6adc8" // Subtext0
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: Performance.cpuTemp.toFixed(1) + "°C"
                        color: "#cdd6f4"
                        font.pixelSize: 16
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#45475a" // Surface1
            }

            // Notification Center Header
            Text {
                text: "Notifications"
                font.pixelSize: 18
                font.bold: true
                color: "#cdd6f4"
                Layout.alignment: Qt.AlignHCenter
            }

            // Notification Center (Takes up the rest of the vertical space)
            NotifCenter {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
