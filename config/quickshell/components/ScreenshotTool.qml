import Quickshell
import "../services"
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // UI state for toggles
    property bool saveToFile: true
    property bool copyToClipboard: true

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-screenshot"
    // Invoke: qs ipc call toggle-screenshot toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-screenshot"

        function toggle(): void {
            screenshotWindow.visible = !screenshotWindow.visible;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Capture execution logic
    // ──────────────────────────────────────────────────────────────────────────
    function runScreenshot(mode) {
        screenshotWindow.visible = false;
        
        // Resolve absolute path to the script
        var scriptPath = Qt.resolvedUrl("../scripts/screenshot.sh").toString().replace("file://", "");
        
        screenshotProc.command = [
            "bash",
            scriptPath,
            mode,
            saveToFile ? "true" : "false",
            copyToClipboard ? "true" : "false"
        ];
        screenshotProc.running = true;
    }

    Process {
        id: screenshotProc
        stdout: SplitParser {
            onRead: data => {
                console.log("[ScreenshotTool] Capture successful: " + data.trim());
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // UI: Full-screen Overlay Window
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: screenshotWindow
        visible: false

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-screenshot"

        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        color:         "transparent"
        exclusionMode: ExclusionMode.Ignore

        Item {
            anchors.fill: parent
            focus: true

            // Global Keybinds
            Keys.onEscapePressed: {
                screenshotWindow.visible = false;
            }

            // Backdrop click to close
            MouseArea {
                anchors.fill: parent
                onClicked: screenshotWindow.visible = false;
                
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.6) // Darker for better focus
                }
            }

            // ──────────────────────────────────────────────────────────────────
            // Selection Card
            // ──────────────────────────────────────────────────────────────────
            Rectangle {
                anchors.centerIn: parent
                width:  400
                height: contentCol.implicitHeight + 48
                radius: 20
                color:        GlobalState.base
                border.color: GlobalState.surface0
                border.width: 1

                // Shadow (simulated)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    z: -1
                    radius: 21
                    color: GlobalState.crust
                    opacity: 0.5
                }

                MouseArea { anchors.fill: parent } // Swallow clicks

                ColumnLayout {
                    id: contentCol
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 24
                    }
                    spacing: 20

                    Text {
                        text: "Screenshot"
                        color: GlobalState.matugenPrimary
                        font.pixelSize: 20
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Mode Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: [
                                { icon: "󰹑", label: "Full",   mode: "full" },
                                { icon: "󰒔", label: "Region", mode: "region" },
                                { icon: "󰖭", label: "Window", mode: "window" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 84
                                radius: 14
                                color: modeArea.containsMouse ? GlobalState.surface0 : GlobalState.mantle
                                border.color: modeArea.containsMouse ? GlobalState.matugenPrimary : GlobalState.surface1
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 28
                                        color: GlobalState.matugenPrimary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.label
                                        font.pixelSize: 13
                                        color: GlobalState.text
                                        font.bold: modeArea.containsMouse
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: modeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: runScreenshot(modelData.mode)
                                }

                                Behavior on color { ColorAnimation { duration: Appearance.popupFade } }
                                Behavior on border.color { ColorAnimation { duration: Appearance.popupFade } }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: GlobalState.surface0
                    }

                    // Options
                    RowLayout {
                        Layout.fillWidth: true
                        
                        // Option: Save
                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 22; height: 22; radius: 6
                                color: root.saveToFile ? GlobalState.matugenPrimary : GlobalState.surface0
                                border.color: GlobalState.surface1
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄬"
                                    visible: root.saveToFile
                                    color: GlobalState.base
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.saveToFile = !root.saveToFile
                                }
                            }
                            Text {
                                text: "Save to File"
                                color: GlobalState.text
                                font.pixelSize: 13
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Option: Copy
                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 22; height: 22; radius: 6
                                color: root.copyToClipboard ? GlobalState.matugenPrimary : GlobalState.surface0
                                border.color: GlobalState.surface1
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄬"
                                    visible: root.copyToClipboard
                                    color: GlobalState.base
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyToClipboard = !root.copyToClipboard
                                }
                            }
                            Text {
                                text: "Clipboard"
                                color: GlobalState.text
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }
        }
    }
}
