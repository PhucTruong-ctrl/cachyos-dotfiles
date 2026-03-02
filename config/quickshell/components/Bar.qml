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
import Quickshell.Services.SystemTray
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

    // Battery icon: level-accurate nerd font glyph, swaps set based on charge state
    readonly property string batteryIcon: {
        var p = BatteryService.percentage
        if (BatteryService.isCharging) {
            if (p <= 10) return "󰢜"
            if (p <= 20) return "󰂆"
            if (p <= 30) return "󰂇"
            if (p <= 40) return "󰂈"
            if (p <= 50) return "󰢝"
            if (p <= 60) return "󰂉"
            if (p <= 70) return "󰢞"
            if (p <= 80) return "󰂊"
            if (p <= 90) return "󰂋"
            return "󰂅"
        } else {
            if (p <= 10) return "󰁺"
            if (p <= 20) return "󰁻"
            if (p <= 30) return "󰁼"
            if (p <= 40) return "󰁽"
            if (p <= 50) return "󰁾"
            if (p <= 60) return "󰁿"
            if (p <= 70) return "󰂀"
            if (p <= 80) return "󰂁"
            if (p <= 90) return "󰂂"
            return "󰁹"
        }
    }

    // Battery color: green=charging, red=critical(isLow ≤14%), yellow=low(≤50%), normal otherwise
    readonly property color batteryColor: {
        if (BatteryService.isCharging)  return GlobalState.success
        if (BatteryService.isLow)       return GlobalState.matugenError
        if (BatteryService.percentage <= 50) return GlobalState.warning
        return GlobalState.matugenOnSurface
    }

    Process {
        id: controlCenterIpc
        command: ["qs", "ipc", "call", "control-center", "toggle"]
    }

    Process {
        id: calProc
        command: ["qs", "ipc", "call", "toggle-calendar", "toggle"]
    }

    // ---------------------------------------------------------------------------
    // One PanelWindow per monitor (handles hotplug correctly via Variants)
    // ---------------------------------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
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
            color: GlobalState.matugenBackground

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

                            color: modelData.focused ? GlobalState.matugenPrimary : GlobalState.matugenSurface

                            Behavior on color {
                                ColorAnimation { duration: Appearance.popupFade }
                            }

                            Text {
                                anchors.centerIn: parent
                                text:  modelData.id > 0 ? modelData.id : modelData.name
                                color: wsPill.modelData.focused ? GlobalState.matugenOnPrimary : GlobalState.matugenOnSurface
                                font.pixelSize: 11
                                font.bold: wsPill.modelData.focused
                            }

                            Rectangle {
                                visible: wsPill.modelData.urgent
                                width:  6
                                height: 6
                                radius: 3
                                color: GlobalState.matugenError
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
                        Text { text: "󰻠"; color: GlobalState.matugenPrimary; font.family: "monospace"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Performance.cpuUsage.toFixed(1) + "%"; color: GlobalState.matugenOnSurface; font.family: "monospace"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                    
                    // RAM
                    Row {
                        spacing: 4
                        Text { text: "󰍛"; color: GlobalState.blue; font.family: "monospace"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Performance.ramUsage.toFixed(1) + "%"; color: GlobalState.matugenOnSurface; font.family: "monospace"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                    
                    // CPU Temp
                    Row {
                        spacing: 4
                        Text { text: "󰔏"; color: GlobalState.matugenError; font.family: "monospace"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Performance.cpuTemp.toFixed(1) + "°C"; color: GlobalState.matugenOnSurface; font.family: "monospace"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
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

                        // System Tray
                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                required property var modelData
                                visible: modelData.status !== SystemTrayItem.Passive
                                width: visible ? 24 : 0
                                height: 24

                                Image {
                                    anchors.centerIn: parent
                                    source: modelData.icon
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                }

                                Rectangle {
                                    visible: modelData.status === SystemTrayItem.NeedsAttention
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: GlobalState.matugenError
                                    anchors {
                                        top: parent.top
                                        right: parent.right
                                        topMargin: 2
                                        rightMargin: 2
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            modelData.display(barWindow, mouse.x, mouse.y)
                                        } else {
                                            if (modelData.onlyMenu) {
                                                modelData.display(barWindow, mouse.x, mouse.y)
                                            } else {
                                                modelData.activate()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 16
                            color: GlobalState.overlay1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Wifi Icon
                        Item {
                            id: wifiTrigger
                            width: 24
                            height: 24
                            
                            Text {
                                anchors.centerIn: parent
                                text: NetworkService.wifiEnabled ? "󰖩" : "󰤭"
                                color: NetworkService.wifiEnabled ? GlobalState.matugenPrimary : GlobalState.overlay1
                                font.pixelSize: 16
                                font.family: "monospace"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        // Capture geometry before opening control center
                                        var pos = wifiTrigger.mapToItem(null, 0, 0)
                                        PopupAnchorService.setAnchor("control-center", pos.x, wifiTrigger.width, barWindow.height)
                                        PopupStateService.toggleExclusive("control-center")
                                        controlCenterIpc.running = false
                                        controlCenterIpc.running = true
                                    } else {
                                        NetworkService.toggleWifi()
                                    }
                                }
                            }
                        }

                        // Bluetooth Icon
                        Item {
                            id: bluetoothTrigger
                            width: 24
                            height: 24
                            
                            Text {
                                anchors.centerIn: parent
                                text: BluetoothService.enabled ? "󰂯" : "󰂲"
                                color: BluetoothService.enabled ? GlobalState.matugenPrimary : GlobalState.overlay1
                                font.pixelSize: 16
                                font.family: "monospace"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        // Capture geometry before opening control center
                                        var pos = bluetoothTrigger.mapToItem(null, 0, 0)
                                        PopupAnchorService.setAnchor("control-center", pos.x, bluetoothTrigger.width, barWindow.height)
                                        PopupStateService.toggleExclusive("control-center")
                                        controlCenterIpc.running = false
                                        controlCenterIpc.running = true
                                    } else {
                                        BluetoothService.togglePower()
                                    }
                                }
                            }
                        }
                    }

                    // Media Widget: compact MPRIS controls (hidden when no player)
                    MediaWidget {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Battery: icon swaps between charging/discharging sets; color signals level
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: barRoot.batteryIcon
                            color: barRoot.batteryColor
                            font.pixelSize: 16
                            font.family: "monospace"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: BatteryService.percentage + "%"
                            color: barRoot.batteryColor
                            font.family: "monospace"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Theme Icon
                    Item {
                        id: themeTrigger
                        width: 20
                        height: 20

                        Text {
                            anchors.centerIn: parent
                            text: "󰸉" // nf-md-wallpaper
                            color: GlobalState.matugenOnSurface
                            font.pixelSize: 16
                            font.family: "monospace"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pos = themeTrigger.mapToItem(null, 0, 0)
                                PopupAnchorService.setAnchor("theme", pos.x, themeTrigger.width, barWindow.height)
                                PopupStateService.toggleExclusive("theme")
                                themeIpc.running = false
                                themeIpc.running = true
                            }
                        }

                        Process {
                            id: themeIpc
                            command: ["qs", "ipc", "call", "toggle-theme", "toggle"]
                        }
                    }

                    // Notification Icon
                    Item {
                        id: notifTrigger
                        width: 20
                        height: 20

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚" // nf-md-bell
                            color: GlobalState.matugenOnSurface
                            font.pixelSize: 16
                            font.family: "monospace"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pos = notifTrigger.mapToItem(null, 0, 0)
                                PopupAnchorService.setAnchor("notifs", pos.x, notifTrigger.width, barWindow.height)
                                PopupStateService.toggleExclusive("notifs")
                                notifIpc.running = false
                                notifIpc.running = true
                            }
                        }

                        Process {
                            id: notifIpc
                            command: ["qs", "ipc", "call", "toggle-notifs", "toggle"]
                        }
                    }

                    // Clock
                    Text {
                        id: clockLabel
                        text: barRoot.clockText
                        color: GlobalState.matugenOnBackground
                        font.pixelSize: 13
                        font.family: "monospace"
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pos = clockLabel.mapToItem(null, 0, 0)
                                PopupAnchorService.setAnchor("calendar", pos.x, clockLabel.width, barWindow.height)
                                PopupStateService.toggleExclusive("calendar")
                                calProc.running = false
                                calProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
