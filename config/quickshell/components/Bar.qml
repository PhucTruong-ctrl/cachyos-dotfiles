// Bar.qml
// Minimal top-panel status bar for Quickshell.
// Renders one PanelWindow per screen so the bar spans every monitor.
// Contains:
//   - Clock: driven by Quickshell's built-in SystemClock (seconds precision)
//   - Workspace indicator: live Repeater bound to Hyprland.workspaces.values
//     Each pill is clickable — calls workspace.activate() to switch.
//     The focused workspace is highlighted in Catppuccin Mocha mauve.

import "../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray

Scope {
    id: barRoot

    readonly property string clockText: Qt.formatDateTime(clock.date, "hh:mm:ss  ddd d MMM")
    // Battery icon: level-accurate nerd font glyph, swaps set based on charge state
    readonly property string batteryIcon: {
        var p = BatteryService.percentage;
        if (BatteryService.isCharging) {
            if (p <= 10)
                return "󰢜";

            if (p <= 20)
                return "󰂆";

            if (p <= 30)
                return "󰂇";

            if (p <= 40)
                return "󰂈";

            if (p <= 50)
                return "󰢝";

            if (p <= 60)
                return "󰂉";

            if (p <= 70)
                return "󰢞";

            if (p <= 80)
                return "󰂊";

            if (p <= 90)
                return "󰂋";

            return "󰂅";
        } else {
            if (p <= 10)
                return "󰁺";

            if (p <= 20)
                return "󰁻";

            if (p <= 30)
                return "󰁼";

            if (p <= 40)
                return "󰁽";

            if (p <= 50)
                return "󰁾";

            if (p <= 60)
                return "󰁿";

            if (p <= 70)
                return "󰂀";

            if (p <= 80)
                return "󰂁";

            if (p <= 90)
                return "󰂂";

            return "󰁹";
        }
    }
    // Battery color: green=charging, red=critical(isLow ≤14%), yellow=low(≤50%), normal otherwise
    readonly property color batteryColor: {
        if (BatteryService.isCharging)
            return GlobalState.success;

        if (BatteryService.isLow)
            return GlobalState.matugenError;

        if (BatteryService.percentage <= 50)
            return GlobalState.warning;

        return GlobalState.matugenOnSurface;
    }

    // ---------------------------------------------------------------------------
    // Clock string — single SystemClock instance shared across all bar windows
    // ---------------------------------------------------------------------------
    SystemClock {
        id: clock

        precision: SystemClock.Seconds
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
            // Bar geometry & background
            implicitHeight: 40
            color: GlobalState.matugenBackground
            exclusiveZone: 40

            // Anchor to the full top edge of the screen
            anchors {
                top: true
                left: true
                right: true
            }

            // ------------------------------------------------------------------
            // Layout: [Workspaces] ——— [System Monitor] ——— [Tray | Icons | Clock]
            // ------------------------------------------------------------------
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                // ── Left section: live workspace pills ────────────────────────
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 16

                    // CPU
                    Row {
                        spacing: 4

                        Text {
                            text: "󰻠"
                            color: GlobalState.matugenPrimary
                            font.family: "JetBrainsMonoNL Nerd Font"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Performance.cpuUsage.toFixed(1) + "%"
                            color: GlobalState.matugenOnSurface
                            font.family: "JetBrainsMonoNL Nerd Font"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    // RAM
                    Row {
                        spacing: 4

                        Text {
                            text: "󰍛"
                            color: GlobalState.blue
                            font.family: "JetBrainsMonoNL Nerd Font"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Performance.ramUsage.toFixed(1) + "%"
                            color: GlobalState.matugenOnSurface
                            font.family: "JetBrainsMonoNL Nerd Font"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    // CPU Temp
                    Row {
                        spacing: 4

                        Text {
                            text: "󰔏"
                            color: GlobalState.matugenError
                            font.family: "JetBrainsMonoNL Nerd Font"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Performance.cpuTemp.toFixed(1) + "°C"
                            color: GlobalState.matugenOnSurface
                            font.family: "JetBrainsMonoNL Nerd Font"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

                // Media Widget: always-visible compact MPRIS controls
                // Shows "No media" when no player, mini visualizer + controls when active.
                // MediaWidget {
                //     Layout.alignment: Qt.AlignVCenter
                // }

                // ── Left spacer ───────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                }

                // ── Middle section: System Monitor ────────────────────────────
                Row {
                    id: workspacesRow

                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: Hyprland.workspaces.values

                        delegate: Rectangle {
                            id: wsPill

                            required property var modelData // HyprlandWorkspace

                            width: 22
                            height: 22
                            radius: 4
                            color: modelData.focused ? GlobalState.matugenPrimary : GlobalState.matugenSurface

                            Text {
                                anchors.centerIn: parent
                                text: modelData.id > 0 ? modelData.id : modelData.name
                                color: wsPill.modelData.focused ? GlobalState.matugenOnPrimary : GlobalState.matugenOnSurface
                                font.pixelSize: 11
                                font.bold: wsPill.modelData.focused
                                font.family: "JetBrainsMonoNL Nerd Font"
                            }

                            Rectangle {
                                visible: wsPill.modelData.urgent
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
                                onClicked: {
                                    wsPill.modelData.activate();
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.popupFade
                                }

                            }

                        }

                    }

                }

                // ── Right spacer ──────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                }

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
                                    source: modelData.icon || ""
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
                                    function showNativeMenu(mouse) {
                                        const menuPos = mapToItem(barWindow.contentItem ?? parent, mouse.x, mouse.y);
                                        modelData.display(barWindow, menuPos.x, menuPos.y);
                                    }

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (modelData.hasMenu)
                                                showNativeMenu(mouse);
                                            else
                                                modelData.secondaryActivate();
                                        } else {
                                            if (modelData.onlyMenu && modelData.hasMenu)
                                                showNativeMenu(mouse);
                                            else
                                                modelData.activate();
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

                            width: 28
                            height: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.barItemRadius
                                color: wifiHover.containsMouse ? GlobalState.matugenSurface : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.barHoverDuration
                                    }

                                }

                            }

                            HoverHandler {
                                id: wifiHover
                            }

                            Text {
                                anchors.centerIn: parent
                                text: NetworkService.wifiEnabled ? "󰖩" : "󰤭"
                                color: NetworkService.wifiEnabled ? GlobalState.matugenPrimary : GlobalState.overlay1
                                font.pixelSize: 16
                                font.family: "monospace"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.popupFade
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pos = wifiTrigger.mapToItem(null, 0, 0);
                                        PopupAnchorService.setAnchor("control-center", pos.x, wifiTrigger.width, barWindow.height);
                                        PopupStateService.toggleExclusive("control-center");
                                    } else {
                                        NetworkService.toggleWifi();
                                    }
                                }
                            }

                        }

                        // Bluetooth Icon
                        Item {
                            id: bluetoothTrigger

                            width: 28
                            height: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.barItemRadius
                                color: btHover.containsMouse ? GlobalState.matugenSurface : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.barHoverDuration
                                    }

                                }

                            }

                            HoverHandler {
                                id: btHover
                            }

                            Text {
                                anchors.centerIn: parent
                                text: BluetoothService.enabled ? "󰂯" : "󰂲"
                                color: BluetoothService.enabled ? GlobalState.matugenPrimary : GlobalState.overlay1
                                font.pixelSize: 16
                                font.family: "monospace"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.popupFade
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pos = bluetoothTrigger.mapToItem(null, 0, 0);
                                        PopupAnchorService.setAnchor("control-center", pos.x, bluetoothTrigger.width, barWindow.height);
                                        PopupStateService.toggleExclusive("control-center");
                                    } else {
                                        BluetoothService.togglePower();
                                    }
                                }
                            }

                        }

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

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.popupFade
                                }

                            }

                        }

                        Text {
                            text: BatteryService.percentage + "%"
                            color: barRoot.batteryColor
                            font.family: "monospace"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.popupFade
                                }

                            }

                        }

                    }

                    // Theme Icon
                    Item {
                        id: themeTrigger

                        width: 28
                        height: 28

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.barItemRadius
                            color: themeHover.containsMouse ? GlobalState.matugenSurface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.barHoverDuration
                                }

                            }

                        }

                        HoverHandler {
                            id: themeHover
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰸉" // nf-md-wallpaper
                            color: themeHover.containsMouse ? GlobalState.matugenPrimary : GlobalState.matugenOnSurface
                            font.pixelSize: 16
                            font.family: "monospace"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.barHoverDuration
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pos = themeTrigger.mapToItem(null, 0, 0);
                                PopupAnchorService.setAnchor("theme", pos.x, themeTrigger.width, barWindow.height);
                                PopupStateService.toggleExclusive("theme");
                            }
                        }

                    }

                    // Notification Icon
                    Item {
                        id: notifTrigger

                        width: 28
                        height: 28

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.barItemRadius
                            color: notifHover.containsMouse ? GlobalState.matugenSurface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.barHoverDuration
                                }

                            }

                        }

                        HoverHandler {
                            id: notifHover
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚" // nf-md-bell
                            color: notifHover.containsMouse ? GlobalState.matugenPrimary : GlobalState.matugenOnSurface
                            font.pixelSize: 16
                            font.family: "monospace"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.barHoverDuration
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pos = notifTrigger.mapToItem(null, 0, 0);
                                PopupAnchorService.setAnchor("notifs", pos.x, notifTrigger.width, barWindow.height);
                                PopupStateService.toggleExclusive("notifs");
                            }
                        }

                    }

                    // Clock — wrapped in hover pill item
                    Item {
                        id: clockTrigger

                        implicitWidth: clockLabel.implicitWidth + 16
                        height: 28
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.barItemRadius
                            color: clockHover.containsMouse ? GlobalState.matugenSurface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.barHoverDuration
                                }

                            }

                        }

                        HoverHandler {
                            id: clockHover
                        }

                        Text {
                            id: clockLabel

                            anchors.centerIn: parent
                            text: barRoot.clockText
                            color: GlobalState.matugenOnBackground
                            font.pixelSize: 13
                            font.family: "monospace"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pos = clockTrigger.mapToItem(null, 0, 0);
                                PopupAnchorService.setAnchor("calendar", pos.x, clockTrigger.width, barWindow.height);
                                PopupStateService.toggleExclusive("calendar");
                            }
                        }

                    }

                }

            }

        }

    }

}
