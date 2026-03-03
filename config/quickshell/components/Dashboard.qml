// Dashboard.qml — Quickshell Dashboard overlay
// 
// Large panel anchored to the right side of the screen containing
// the Notification Center, System Monitoring, and Wallpaper Matrix.
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

    // Full screen so backdrop can dismiss on click-outside
    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-dashboard"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    visible: false

    // Sync visibility from PopupStateService (single-open coordination)
    Connections {
        target: PopupStateService
        function onOpenPopupIdChanged() {
            root.visible = (PopupStateService.openPopupId === "dashboard")
        }
    }

    IpcHandler {
        target: "toggle-dashboard"
        function toggle(): void { PopupStateService.toggleExclusive("dashboard") }
        function show(): void   { PopupStateService.openExclusive("dashboard") }
        function hide(): void   {
            if (PopupStateService.openPopupId === "dashboard") PopupStateService.closeAll()
        }
    }

    // Keep track of active tab (0 = SysMon/Notifs, 1 = Wallpapers)
    property int currentTab: 0

    // Backdrop — click outside closes the panel
    MouseArea {
        anchors.fill: parent
        onClicked:    PopupStateService.closeAll()
    }

    // Panel content — anchored below trigger icon, full height strip
    Rectangle {
        x:      PopupAnchorService.popupXFor(450, parent.width)
        y:      PopupAnchorService.barY + 4
        width:  450
        height: parent.height - PopupAnchorService.barY - 12
        color: Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
        radius: 12
        border.color: GlobalState.mauve
        border.width: 1

        MouseArea { anchors.fill: parent } // absorb clicks

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // Tabs Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: root.currentTab === 0 ? GlobalState.surface1 : GlobalState.surface0
                    radius: 8
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰕮 System" // nf-md-view_dashboard
                        font.family: "monospace"
                        font.pixelSize: 14
                        font.bold: root.currentTab === 0
                        color: root.currentTab === 0 ? GlobalState.mauve : GlobalState.subtext1
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 0
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: root.currentTab === 1 ? GlobalState.surface1 : GlobalState.surface0
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: "󰸉 Wallpapers" // nf-md-wallpaper
                        font.family: "monospace"
                        font.pixelSize: 14
                        font.bold: root.currentTab === 1
                        color: root.currentTab === 1 ? GlobalState.mauve : GlobalState.subtext1
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 1
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: GlobalState.surface1
            }

            // StackLayout equivalent using visible properties for simple toggle
            // -- Tab 0: System Monitoring & Notifications --
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16
                visible: root.currentTab === 0

                // Performance Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // CPU
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        color: GlobalState.surface0
                        radius: 8
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            Text {
                                text: "CPU"
                                color: GlobalState.subtext0
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: Performance.cpuUsage.toFixed(1) + "%"
                                color: GlobalState.text
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
                        color: GlobalState.surface0
                        radius: 8
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            Text {
                                text: "RAM"
                                color: GlobalState.subtext0
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: Performance.ramUsage.toFixed(1) + "%"
                                color: GlobalState.text
                                font.pixelSize: 20
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // CPU Temp
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        color: GlobalState.surface0
                        radius: 8

                        ColumnLayout {
                            anchors.centerIn: parent
                            Text {
                                text: "TEMP"
                                color: GlobalState.subtext0
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: Performance.cpuTemp.toFixed(1) + "°C"
                                color: GlobalState.text
                                font.pixelSize: 20
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: GlobalState.surface1
                }

                // Notifications Header
                Text {
                    text: "Notifications"
                    font.pixelSize: 16
                    font.bold: true
                    color: GlobalState.text
                }

                // Notification Center
                NotifCenter {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            // -- Tab 1: Wallpapers (ThemeMatrix) --
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTab === 1

                ThemeMatrix {
                    id: themeMatrix
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    cellWidth: 194  // Adjusted for 450px width panel
                    cellHeight: 120
                    clip: true
                }
            }
        }
    }
}
