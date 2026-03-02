// ControlCenter.qml — Quick control panel, anchored top-right
//
// Toggle via: qs ipc call control-center toggle|show|hide
//
// Contains:
//   - Quick toggles: WiFi, Bluetooth, Night Mode, Caffeine, DND, Airplane Mode
//   - Volume and Brightness sliders (rewritten with GlobalState colors
//     instead of hardcoded hex values)
//   - Expandable sub-panels: WiFi network list, Bluetooth device list
//
// Animation: slide-down from top, Appearance.panelSlide ms, Appearance.standardDecel
// Colors: ALL from GlobalState — no hardcoded Catppuccin hex values

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services"

PanelWindow {
    id: root

    // ── Position: full screen so backdrop can dismiss on click-outside ─────────
    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode:               ExclusionMode.Ignore

    color:   "transparent"
    visible: false

    // ── Open / close state ────────────────────────────────────────────────────
    property bool open: false

    onOpenChanged: {
        if (open) {
            // Reset content to off-screen starting position before revealing
            contentRect.y = -(contentRect.height + 12)
            visible = true
            slideInAnim.restart()
        } else {
            slideOutAnim.restart()
        }
    }

    // ── IPC handler ───────────────────────────────────────────────────────────
    IpcHandler {
        target: "control-center"
        function toggle(): void {
            root.open = !root.open
            console.log("ControlCenter: visible=" + root.open)
        }
        function show(): void {
            if (!root.open) {
                root.open = true
                console.log("ControlCenter: visible=true")
            }
        }
        function hide(): void {
            if (root.open) {
                root.open = false
                console.log("ControlCenter: visible=false")
            }
        }
    }

    // ── Slide-in: off-screen → y=0, Appearance.standardDecel ────────────────
    NumberAnimation {
        id:           slideInAnim
        target:       contentRect
        property:     "y"
        to:           0
        duration:     Appearance.panelSlide
        easing.type:  Appearance.standardDecel
    }

    // ── Slide-out: y=0 → off-screen, Appearance.standardAccel ────────────────
    NumberAnimation {
        id:           slideOutAnim
        target:       contentRect
        property:     "y"
        to:           -(contentRect.height + 12)
        duration:     Appearance.contentSwitch
        easing.type:  Appearance.standardAccel
        onStopped:    root.visible = false
    }

    // ── Sub-panel expansion state ─────────────────────────────────────────────
    property bool wifiExpanded: false
    property bool btExpanded:   false

    // ── Volume state ──────────────────────────────────────────────────────────
    property int  currentVolume: 0
    property bool isMuted:       false

    Process {
        id:      pamixerGetVolume
        command: ["pamixer", "--get-volume"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const v = parseInt(data.trim())
                if (!isNaN(v)) {
                    root.currentVolume = v
                    if (!volSlider.pressed) volSlider.value = v
                }
            }
        }
    }

    Process {
        id:      pamixerGetMute
        command: ["pamixer", "--get-mute"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.isMuted = (data.trim() === "true")
            }
        }
    }

    Process {
        id: pamixerSetVolume
        property int targetVol: 0
        command: ["pamixer", "--set-volume", targetVol.toString()]
        onExited: pamixerGetVolume.running = true
    }

    Process {
        id:      pamixerToggleMute
        command: ["pamixer", "--toggle-mute"]
        onExited: pamixerGetMute.running = true
    }

    // ── Brightness state ──────────────────────────────────────────────────────
    property int currentBrightness: 50
    property int maxBrightness:     100

    Process {
        id:      brightnessGetMax
        command: ["brightnessctl", "m"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const max = parseInt(data.trim())
                if (!isNaN(max) && max > 0) {
                    root.maxBrightness = max
                    brightnessGet.running = true
                }
            }
        }
    }

    Process {
        id:      brightnessGet
        command: ["brightnessctl", "g"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const val = parseInt(data.trim())
                if (!isNaN(val) && root.maxBrightness > 0) {
                    const pct = Math.round((val / root.maxBrightness) * 100)
                    root.currentBrightness = pct
                    if (!brightSlider.pressed) brightSlider.value = pct
                }
            }
        }
    }

    Process {
        id: brightnessSet
        property int targetPercent: 0
        command: ["brightnessctl", "set", targetPercent.toString() + "%"]
        onExited: brightnessGet.running = true
    }

    // ── Night Mode processes ──────────────────────────────────────────────────
    Process {
        id:      wlsunsetCheck
        command: ["pgrep", "-x", "wlsunset"]
        running: true
        onExited: (code) => { GlobalState.nightModeActive = (code === 0) }
    }

    Process {
        id:      wlsunsetStart
        command: ["wlsunset", "-t", "4000", "-T", "6500"]
        onExited: wlsunsetCheck.running = true
    }

    Process {
        id:      wlsunsetKill
        command: ["pkill", "-x", "wlsunset"]
        onExited: wlsunsetCheck.running = true
    }

    // ── Caffeine processes ────────────────────────────────────────────────────
    Process {
        id:      caffeineCheck
        command: ["pgrep", "-x", "hypridle"]
        running: true
        // hypridle NOT running → screen-saver inhibited → "caffeine" is active
        onExited: (code) => { GlobalState.caffeineActive = (code !== 0) }
    }

    Process {
        id:      hypridleStart
        command: ["hypridle"]
        onExited: caffeineCheck.running = true
    }

    Process {
        id:      hypridleKill
        command: ["pkill", "-x", "hypridle"]
        onExited: caffeineCheck.running = true
    }

    // ── Polling timer (runs only while panel is open) ─────────────────────────
    Timer {
        interval: 2000
        running:  root.open
        repeat:   true
        onTriggered: {
            pamixerGetVolume.running = true
            pamixerGetMute.running   = true
            brightnessGet.running    = true
            wlsunsetCheck.running    = true
            caffeineCheck.running    = true
        }
    }

    // ── Inline component: CustomSlider ────────────────────────────────────────
    // Custom slider component using GlobalState colors exclusively.
    component CustomSlider: Slider {
        id: sliderCtrl

        background: Rectangle {
            x:              sliderCtrl.leftPadding
            y:              sliderCtrl.topPadding + sliderCtrl.availableHeight / 2 - height / 2
            implicitWidth:  200
            implicitHeight: 8
            width:          sliderCtrl.availableWidth
            height:         implicitHeight
            radius:         4
            color:          GlobalState.surface0

            Rectangle {
                width:  sliderCtrl.visualPosition * parent.width
                height: parent.height
                color:  GlobalState.matugenPrimary
                radius: 4
            }
        }

        handle: Rectangle {
            x:              sliderCtrl.leftPadding + sliderCtrl.visualPosition * (sliderCtrl.availableWidth - width)
            y:              sliderCtrl.topPadding + sliderCtrl.availableHeight / 2 - height / 2
            implicitWidth:  16
            implicitHeight: 16
            radius:         8
            color:          sliderCtrl.pressed ? GlobalState.matugenError : GlobalState.matugenPrimary
            border.color:   GlobalState.base
            border.width:   2
        }
    }

    // ── Inline component: ToggleButton ────────────────────────────────────────
    component ToggleButton: Rectangle {
        id: btn
        property string iconText:  ""
        property string labelText: ""
        property bool   active:    false
        signal clicked()

        Layout.fillWidth:       true
        Layout.preferredHeight: 64
        radius:       8
        color:        active ? GlobalState.matugenPrimary : GlobalState.surface0
        border.color: active ? GlobalState.lavender       : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing:          2

            Text {
                text:             btn.iconText
                color:            btn.active ? GlobalState.matugenOnPrimary : GlobalState.text
                font.pixelSize:   18
                font.family:      "monospace"
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text:             btn.labelText
                color:            btn.active ? GlobalState.matugenOnPrimary : GlobalState.subtext1
                font.pixelSize:   11
                Layout.alignment: Qt.AlignHCenter
                wrapMode:         Text.NoWrap
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    btn.clicked()
        }
    }

    // ── Backdrop — click outside content closes the panel ────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked:    root.open = false
    }

    // ── Main content rectangle ────────────────────────────────────────────────
    Rectangle {
        id:            contentRect
        anchors.right: parent.right
        y:             0
        width:         400
        height:        mainColumn.implicitHeight + 24
        color:  GlobalState.base
        radius: Appearance.panelRadius
        border.color: GlobalState.matugenPrimary
        border.width: 1
        clip:   true

        MouseArea { anchors.fill: parent } // absorb clicks — prevent backdrop from firing

        ColumnLayout {
            id:      mainColumn
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: 16
            spacing: 12

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:             "Control Center"
                    color:            GlobalState.text
                    font.pixelSize:   16
                    font.bold:        true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width:  24
                    height: 24
                    radius: 4
                    color:  closeHover.containsMouse ? GlobalState.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text:           "✕"
                        color:          GlobalState.subtext0
                        font.pixelSize: 13
                    }

                    HoverHandler { id: closeHover }

                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     root.open = false
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                color:                  GlobalState.surface1
            }

            // ── Toggle Grid (2 columns × 3 rows = 6 toggles) ─────────────────
            GridLayout {
                columns:       2
                rowSpacing:    8
                columnSpacing: 8
                Layout.fillWidth: true

                // ── WiFi toggle (primary = on/off, expand arrow = show list) ──
                Rectangle {
                    id:                     wifiCell
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 64
                    radius:       8
                    color:        NetworkService.wifiEnabled ? GlobalState.matugenPrimary : GlobalState.surface0
                    border.color: NetworkService.wifiEnabled ? GlobalState.lavender       : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing:          2

                        Text {
                            text:             NetworkService.wifiEnabled ? "󰖩" : "󰤭"
                            color:            NetworkService.wifiEnabled ? GlobalState.matugenOnPrimary : GlobalState.text
                            font.pixelSize:   18
                            font.family:      "monospace"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: {
                                if (!NetworkService.wifiEnabled) return "WiFi"
                                return NetworkService.activeConnection.length > 0
                                    ? NetworkService.activeConnection
                                    : "WiFi On"
                            }
                            color:            NetworkService.wifiEnabled ? GlobalState.matugenOnPrimary : GlobalState.subtext1
                            font.pixelSize:   11
                            elide:            Text.ElideRight
                            Layout.maximumWidth: wifiCell.width - 34
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Expand arrow — higher z, catches click before main toggle
                    MouseArea {
                        z:           1
                        anchors.right:  parent.right
                        anchors.top:    parent.top
                        width:       28
                        height:      28
                        cursorShape: Qt.PointingHandCursor
                        onClicked:   root.wifiExpanded = !root.wifiExpanded

                        Text {
                            anchors.centerIn: parent
                            text:           root.wifiExpanded ? "󰅁" : "󰅂"
                            color:          NetworkService.wifiEnabled ? GlobalState.matugenOnPrimary : GlobalState.subtext0
                            font.pixelSize: 12
                            font.family:    "monospace"
                        }
                    }

                    // Main toggle — full area, lower z
                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     NetworkService.toggleWifi()
                    }
                }

                // ── Bluetooth toggle (primary = on/off, expand arrow = show list)
                Rectangle {
                    id:                     btCell
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 64
                    radius:       8
                    color:        BluetoothService.enabled ? GlobalState.matugenPrimary : GlobalState.surface0
                    border.color: BluetoothService.enabled ? GlobalState.lavender       : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing:          2

                        Text {
                            text:             BluetoothService.enabled ? "󰂯" : "󰂲"
                            color:            BluetoothService.enabled ? GlobalState.matugenOnPrimary : GlobalState.text
                            font.pixelSize:   18
                            font.family:      "monospace"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: {
                                if (!BluetoothService.enabled) return "Bluetooth"
                                const c = BluetoothService.connectedCount
                                return c > 0 ? c + " connected" : "BT On"
                            }
                            color:            BluetoothService.enabled ? GlobalState.matugenOnPrimary : GlobalState.subtext1
                            font.pixelSize:   11
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Expand arrow — higher z
                    MouseArea {
                        z:           1
                        anchors.right:  parent.right
                        anchors.top:    parent.top
                        width:       28
                        height:      28
                        cursorShape: Qt.PointingHandCursor
                        onClicked:   root.btExpanded = !root.btExpanded

                        Text {
                            anchors.centerIn: parent
                            text:           root.btExpanded ? "󰅁" : "󰅂"
                            color:          BluetoothService.enabled ? GlobalState.matugenOnPrimary : GlobalState.subtext0
                            font.pixelSize: 12
                            font.family:    "monospace"
                        }
                    }

                    // Main toggle — lower z
                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     BluetoothService.togglePower()
                    }
                }

                // ── Night Mode ────────────────────────────────────────────────
                ToggleButton {
                    iconText:  GlobalState.nightModeActive ? "󰖔" : "󰖙"
                    labelText: "Night Mode"
                    active:    GlobalState.nightModeActive
                    onClicked: {
                        if (GlobalState.nightModeActive) {
                            wlsunsetKill.running = true
                        } else {
                            wlsunsetStart.running = true
                        }
                        GlobalState.nightModeActive = !GlobalState.nightModeActive
                    }
                }

                // ── Caffeine ──────────────────────────────────────────────────
                ToggleButton {
                    iconText:  "󰅶"
                    labelText: "Caffeine"
                    active:    GlobalState.caffeineActive
                    onClicked: {
                        if (GlobalState.caffeineActive) {
                            // Caffeine active → hypridle was killed; restart it
                            hypridleStart.running = true
                        } else {
                            // Caffeine inactive → kill hypridle to inhibit idle
                            hypridleKill.running = true
                        }
                        GlobalState.caffeineActive = !GlobalState.caffeineActive
                    }
                }

                // ── Do Not Disturb ────────────────────────────────────────────
                ToggleButton {
                    iconText:  GlobalState.dndActive ? "󰂛" : "󰂚"
                    labelText: "Do Not Disturb"
                    active:    GlobalState.dndActive
                    onClicked: {
                        GlobalState.dndActive = !GlobalState.dndActive
                        console.log("ControlCenter: DND=" + GlobalState.dndActive)
                    }
                }

                // ── Airplane Mode (disables WiFi + Bluetooth) ─────────────────
                ToggleButton {
                    property bool isAirplane: !NetworkService.wifiEnabled && !BluetoothService.enabled
                    iconText:  "󰀝"
                    labelText: "Airplane"
                    active:    isAirplane
                    onClicked: {
                        if (isAirplane) {
                            // Leave airplane mode: re-enable both radios
                            if (!NetworkService.wifiEnabled) NetworkService.toggleWifi()
                            if (!BluetoothService.enabled)   BluetoothService.togglePower()
                        } else {
                            // Enter airplane mode: disable both radios
                            if (NetworkService.wifiEnabled)  NetworkService.toggleWifi()
                            if (BluetoothService.enabled)    BluetoothService.togglePower()
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                color:                  GlobalState.surface1
            }

            // ── Volume slider ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                // Mute button (icon reflects state; click toggles mute)
                Rectangle {
                    width:  32
                    height: 32
                    radius: 16
                    color:  root.isMuted ? GlobalState.matugenError : GlobalState.surface1

                    Text {
                        anchors.centerIn: parent
                        text:           root.isMuted ? "󰝟" : (root.currentVolume > 50 ? "󰕾" : "󰖀")
                        color:          root.isMuted ? GlobalState.crust : GlobalState.text
                        font.pixelSize: 16
                        font.family:    "monospace"
                    }

                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     pamixerToggleMute.running = true
                    }
                }

                CustomSlider {
                    id:    volSlider
                    Layout.fillWidth: true
                    from:  0
                    to:    Math.max(100, root.currentVolume)
                    value: 0
                    onMoved: {
                        pamixerSetVolume.targetVol = Math.round(value)
                        pamixerSetVolume.running   = true
                        root.currentVolume = Math.round(value)
                    }
                }

                Text {
                    text:                root.currentVolume + "%"
                    color:               GlobalState.subtext0
                    font.pixelSize:      12
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }
            }

            // ── Brightness slider ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing:          12

                Rectangle {
                    width:  32
                    height: 32
                    radius: 16
                    color:  GlobalState.surface1

                    Text {
                        anchors.centerIn: parent
                        text:           "󰃠"
                        color:          GlobalState.text
                        font.pixelSize: 16
                        font.family:    "monospace"
                    }
                }

                CustomSlider {
                    id:    brightSlider
                    Layout.fillWidth: true
                    from:  1
                    to:    100
                    value: 100
                    onMoved: {
                        brightnessSet.targetPercent = Math.round(value)
                        brightnessSet.running       = true
                        root.currentBrightness = Math.round(value)
                    }
                }

                Text {
                    text:                root.currentBrightness + "%"
                    color:               GlobalState.subtext0
                    font.pixelSize:      12
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }
            }

            // ── WiFi network list (shown when wifiExpanded = true) ────────────
            ColumnLayout {
                visible:          root.wifiExpanded
                Layout.fillWidth: true
                spacing:          6

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 1
                    color:                  GlobalState.surface1
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:             "  Networks"
                        color:            GlobalState.subtext0
                        font.pixelSize:   12
                        font.bold:        true
                        font.family:      "monospace"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth:  76
                        implicitHeight: 24
                        radius:         4
                        color:          scanNetHover.containsMouse ? GlobalState.surface1 : GlobalState.surface0

                        Text {
                            anchors.centerIn: parent
                            text:           NetworkService.scanning ? "Scanning…" : "  Scan"
                            color:          GlobalState.matugenPrimary
                            font.pixelSize: 11
                            font.family:    "monospace"
                        }

                        HoverHandler { id: scanNetHover }

                        MouseArea {
                            anchors.fill:  parent
                            cursorShape:   Qt.PointingHandCursor
                            onClicked:     NetworkService.scanNetworks()
                        }
                    }
                }

                Repeater {
                    model: NetworkService.networkList

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight:   44
                        radius:           6
                        color:            modelData.active
                                              ? GlobalState.matugenPrimary
                                              : (netItemHover.containsMouse ? GlobalState.surface1 : GlobalState.surface0)
                        Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                        RowLayout {
                            anchors.fill:    parent
                            anchors.margins: 10
                            spacing:         8

                            // Signal-strength icon
                            Text {
                                text: modelData.active ? "󰖩" :
                                      (modelData.signal >= 67 ? "󰤨" :
                                       modelData.signal >= 34 ? "󰤥" : "󰤢")
                                color:          modelData.active ? GlobalState.matugenOnPrimary : GlobalState.text
                                font.pixelSize: 16
                                font.family:    "monospace"
                            }

                            Text {
                                text:             modelData.ssid.length > 0 ? modelData.ssid : "(Hidden)"
                                color:            modelData.active ? GlobalState.matugenOnPrimary : GlobalState.text
                                font.pixelSize:   12
                                Layout.fillWidth: true
                                elide:            Text.ElideRight
                            }

                            // Lock icon (secured networks)
                            Text {
                                visible:        modelData.security.length > 0 && modelData.security !== "--"
                                text:           "󰌆"
                                color:          modelData.active ? GlobalState.matugenOnPrimary : GlobalState.subtext0
                                font.pixelSize: 12
                                font.family:    "monospace"
                            }

                            Text {
                                text:           modelData.signal + "%"
                                color:          modelData.active ? GlobalState.matugenOnPrimary : GlobalState.subtext0
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler { id: netItemHover }

                        MouseArea {
                            anchors.fill:  parent
                            cursorShape:   Qt.PointingHandCursor
                            onClicked: {
                                if (!modelData.active) {
                                    NetworkService.connectToNetwork(modelData.ssid, "")
                                }
                            }
                        }
                    }
                }
            }

            // ── Bluetooth device list (shown when btExpanded = true) ──────────
            ColumnLayout {
                visible:          root.btExpanded
                Layout.fillWidth: true
                spacing:          6

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 1
                    color:                  GlobalState.surface1
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:             "󰂯 Devices"
                        color:            GlobalState.subtext0
                        font.pixelSize:   12
                        font.bold:        true
                        font.family:      "monospace"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth:  60
                        implicitHeight: 24
                        radius:         4
                        color:          btScanHover.containsMouse ? GlobalState.surface1 : GlobalState.surface0
                        visible:        BluetoothService.adapterAvailable

                        Text {
                            anchors.centerIn: parent
                            text:           "  Scan"
                            color:          GlobalState.matugenPrimary
                            font.pixelSize: 11
                            font.family:    "monospace"
                        }

                        HoverHandler { id: btScanHover }

                        MouseArea {
                            anchors.fill:  parent
                            cursorShape:   Qt.PointingHandCursor
                            onClicked:     BluetoothService.startDiscovery()
                        }
                    }
                }

                // Fallback when no adapter
                Text {
                    visible:          !BluetoothService.adapterAvailable
                    text:             "No Bluetooth adapter available"
                    color:            GlobalState.subtext0
                    font.pixelSize:   12
                    Layout.alignment: Qt.AlignHCenter
                }

                Repeater {
                    model: BluetoothService.adapterAvailable ? BluetoothService.devices : 0

                    delegate: Rectangle {
                        required property var modelData  // BluetoothDevice
                        Layout.fillWidth: true
                        implicitHeight:   44
                        radius:           6
                        color:            modelData.connected
                                              ? GlobalState.matugenPrimary
                                              : (btItemHover.containsMouse ? GlobalState.surface1 : GlobalState.surface0)
                        Behavior on color { ColorAnimation { duration: Appearance.popupFade } }

                        RowLayout {
                            anchors.fill:    parent
                            anchors.margins: 10
                            spacing:         8

                            Text {
                                text:           modelData.connected ? "󰂱" : "󰂯"
                                color:          modelData.connected ? GlobalState.matugenOnPrimary : GlobalState.text
                                font.pixelSize: 16
                                font.family:    "monospace"
                            }

                            Text {
                                text:             modelData.name
                                color:            modelData.connected ? GlobalState.matugenOnPrimary : GlobalState.text
                                font.pixelSize:   12
                                Layout.fillWidth: true
                                elide:            Text.ElideRight
                            }

                            // Battery percentage (when device reports it)
                            Text {
                                visible:        modelData.batteryAvailable
                                text:           modelData.battery + "%"
                                color:          modelData.connected ? GlobalState.matugenOnPrimary : GlobalState.subtext0
                                font.pixelSize: 11
                            }
                        }

                        HoverHandler { id: btItemHover }

                        MouseArea {
                            anchors.fill:  parent
                            cursorShape:   Qt.PointingHandCursor
                            onClicked: {
                                // BluetoothDevice: set connected=true → connect(), false → disconnect()
                                modelData.connected = !modelData.connected
                            }
                        }
                    }
                }
            }

            // Bottom spacer (ensures padding below last section)
            Item { Layout.preferredHeight: 4 }
        }
    }
}
