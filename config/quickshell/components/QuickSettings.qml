// QuickSettings.qml
// Slide-in quick-settings panel for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-quicksettings toggle
// Keybind example (hyprland.conf):
//   bind = SUPER, S, exec, qs ipc call toggle-quicksettings toggle
//
// Design:
//   - PanelWindow anchored top + right, slides down from the top-right corner.
//   - Volume slider: queries `wpctl get-volume @DEFAULT_AUDIO_SINK@`, sets via
//     `wpctl set-volume @DEFAULT_AUDIO_SINK@ <val>%`.
//   - Brightness slider: queries `brightnessctl get` and `brightnessctl m`,
//     sets via `brightnessctl s <val>%`.
//   - Sliders use `onMoved` (NOT `onValueChanged`) to prevent feedback loops
//     when the slider value is programmatically updated from a system poll.
//   - Pressing Escape or clicking the backdrop closes the panel.
//   - Polled once on open (not on a continuous timer) to avoid unnecessary
//     subprocess churn while the panel is hidden.
//
// MUST NOT: create infinite loops — slider value writes only happen in onMoved.
// MUST NOT: use Waybar, Mako, or any component other than Quickshell primitives.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // Internal state — slider positions driven by system poll, never by
    // the slider's own onValueChanged to avoid feedback loops.
    // ──────────────────────────────────────────────────────────────────────────

    // Volume: 0–100 (integer percent)
    property int volumeLevel: 65

    // Brightness: 0–100 (integer percent, derived from brightnessctl get/max)
    property int brightnessLevel: 50

    // Raw max brightness from `brightnessctl m` — resolved once on startup
    property int brightnessMax: 19200

    // Guard flag: true while a slider-driven write is in flight, so the
    // subsequent poll update doesn't race and snap the slider back mid-drag.
    property bool volumeWriting:     false
    property bool brightnessWriting: false

    // ──────────────────────────────────────────────────────────────────────────
    // Action toggle states
    //   nightModeActive  — true when wlsunset is running
    //   gameModeActive   — true when hyprland blur is disabled (game mode on)
    //   caffeineActive   — true when hypridle is in STOP state (idle inhibited)
    // ──────────────────────────────────────────────────────────────────────────
    property bool nightModeActive:  false
    property bool gameModeActive:   false
    property bool caffeineActive:   false

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-quicksettings"
    // Invoke: qs ipc call toggle-quicksettings toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-quicksettings"

        function toggle(): void {
            console.log("[QuickSettings] IPC toggle called — visible was: " + panel.visible);
            panel.visible = !panel.visible;
            if (panel.visible) {
                console.log("[QuickSettings] opening — polling system state");
                // Refresh both values when the panel opens so sliders are accurate
                volGetProc.running  = true;
                briGetProc.running  = true;
                briMaxProc.running  = true;
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: query current volume
    // Output: "Volume: 0.65\n"  (or "Volume: 0.65 [MUTED]")
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: volGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                // Match "Volume: 0.65" or "Volume: 0.65 [MUTED]"
                const m = raw.match(/Volume:\s+([\d.]+)/);
                if (!m) {
                    console.log("[QuickSettings] volGetProc: unexpected output: " + raw);
                    return;
                }
                const pct = Math.round(parseFloat(m[1]) * 100);
                console.log("[QuickSettings] volGetProc: parsed " + raw + " → " + pct + "%");
                if (!root.volumeWriting) {
                    root.volumeLevel = Math.max(0, Math.min(100, pct));
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: set volume (fire-and-forget)
    // Called from Slider.onMoved with the new percent value.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: volSetProc
        // command is set dynamically before running = true

        onRunningChanged: {
            if (!running) {
                root.volumeWriting = false;
                console.log("[QuickSettings] volSetProc finished");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: query max brightness
    // Output: "19200\n"
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: briMaxProc
        command: ["brightnessctl", "m"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                const n = parseInt(raw, 10);
                if (isNaN(n) || n <= 0) {
                    console.log("[QuickSettings] briMaxProc: unexpected output: " + raw);
                    return;
                }
                console.log("[QuickSettings] briMaxProc: max brightness = " + n);
                root.brightnessMax = n;
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: query current brightness
    // Output: "15360\n"  (raw value, not percent)
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: briGetProc
        command: ["brightnessctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                const cur = parseInt(raw, 10);
                if (isNaN(cur) || root.brightnessMax <= 0) {
                    console.log("[QuickSettings] briGetProc: unexpected output: " + raw);
                    return;
                }
                const pct = Math.round((cur / root.brightnessMax) * 100);
                console.log("[QuickSettings] briGetProc: " + cur + "/" + root.brightnessMax
                    + " → " + pct + "%");
                if (!root.brightnessWriting) {
                    root.brightnessLevel = Math.max(1, Math.min(100, pct));
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Process: set brightness (fire-and-forget)
    // Called from Slider.onMoved with the new percent string e.g. "80%".
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: briSetProc
        // command is set dynamically before running = true

        onRunningChanged: {
            if (!running) {
                root.brightnessWriting = false;
                console.log("[QuickSettings] briSetProc finished");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // IPC target — also respond to "toggle-control-center" so the keybind that
    // was advertised in shell.qml ("toggle-control-center") works in addition to
    // "toggle-quicksettings".
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-control-center"

        function toggle(): void {
            console.log("[QuickSettings] toggle-control-center IPC — visible was: " + panel.visible);
            panel.visible = !panel.visible;
            if (panel.visible) {
                volGetProc.running      = true;
                briGetProc.running      = true;
                briMaxProc.running      = true;
                nightModeProbe.running  = true;
                gameModeProbe.running   = true;
                caffeineProbe.running   = true;
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Night Mode probe — pidof wlsunset
    // Exit 0 + non-empty stdout  → wlsunset is running (night mode active)
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: nightModeProbe
        command: ["pidof", "wlsunset"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.nightModeActive = this.text.trim() !== "";
                console.log("[QuickSettings] nightMode active=" + root.nightModeActive);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Game Mode probe — hyprctl getoption decoration:blur:enabled
    // "int: 0" in the output means blur is OFF → game mode is ON
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: gameModeProbe
        command: ["hyprctl", "getoption", "decoration:blur:enabled"]

        stdout: StdioCollector {
            onStreamFinished: {
                const val = this.text.trim();
                root.gameModeActive = val.includes("int: 0") || val.includes("int:0");
                console.log("[QuickSettings] gameMode active=" + root.gameModeActive
                    + " raw='" + val + "'");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Caffeine probe — ps stat of hypridle process
    // State "T" (stopped) → caffeine is active (idle inhibited)
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: caffeineProbe
        command: ["sh", "-c", "ps -C hypridle -o stat= 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const stat = this.text.trim();
                root.caffeineActive = stat.startsWith("T");
                console.log("[QuickSettings] caffeine active=" + root.caffeineActive
                    + " stat='" + stat + "'");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Night Mode action processes
    // ──────────────────────────────────────────────────────────────────────────
    Process { id: nightModeOn;  command: ["sh", "-c", "wlsunset &"] }
    Process { id: nightModeOff; command: ["pkill", "wlsunset"] }

    // ──────────────────────────────────────────────────────────────────────────
    // Game Mode action processes
    // blur enabled=0 → game mode ON;  enabled=1 → game mode OFF
    // ──────────────────────────────────────────────────────────────────────────
    Process { id: gameModeOn;  command: ["hyprctl", "keyword", "decoration:blur:enabled", "0"] }
    Process { id: gameModeOff; command: ["hyprctl", "keyword", "decoration:blur:enabled", "1"] }

    // ──────────────────────────────────────────────────────────────────────────
    // Caffeine action processes
    // STOP signal → suspends hypridle (no idle triggers); CONT resumes it
    // ──────────────────────────────────────────────────────────────────────────
    Process { id: caffeineOn;  command: ["killall", "-STOP", "hypridle"] }
    Process { id: caffeineOff; command: ["killall", "-CONT", "hypridle"] }

    // ──────────────────────────────────────────────────────────────────────────
    // Delayed re-probes after toggle (allow subprocesses to settle ~800 ms)
    // ──────────────────────────────────────────────────────────────────────────
    Timer {
        id: nightProbeDelay
        interval: 800; repeat: false
        onTriggered: nightModeProbe.running = true
    }
    Timer {
        id: gameModeDelay
        interval: 800; repeat: false
        onTriggered: gameModeProbe.running = true
    }
    Timer {
        id: caffeineDelay
        interval: 800; repeat: false
        onTriggered: caffeineProbe.running = true
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: apply volume change from slider interaction
    // ──────────────────────────────────────────────────────────────────────────
    function applyVolume(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));
        console.log("[QuickSettings] applyVolume: " + clamped + "%");
        root.volumeLevel   = clamped;
        root.volumeWriting = true;
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped + "%"];
        volSetProc.running = true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: apply brightness change from slider interaction
    // ──────────────────────────────────────────────────────────────────────────
    function applyBrightness(pct) {
        const clamped = Math.max(1, Math.min(100, Math.round(pct)));
        console.log("[QuickSettings] applyBrightness: " + clamped + "%");
        root.brightnessLevel   = clamped;
        root.brightnessWriting = true;
        briSetProc.command = ["brightnessctl", "s", clamped + "%"];
        briSetProc.running = true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Bootstrap: query brightnessctl max once at component creation time so we
    // have a valid divisor before the first panel open.
    // ──────────────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        briMaxProc.running = true;
        volGetProc.running = true;
        briGetProc.running = true;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Panel Window — top-right anchor, slide-down quick-settings card
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: panel

        // Hidden on startup — IPC toggle reveals it
        visible: false

        // Anchored to top-right; width determined by content
        anchors {
            top:   true
            right: true
        }

        implicitWidth:  320
        implicitHeight: panelCard.implicitHeight + 2   // 1px border on each side

        // Transparent shell; the card Rectangle paints the background
        color: "transparent"

        // Float above all windows without stealing exclusive zone space
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-quicksettings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Escape → close panel
        Keys.onEscapePressed: {
            console.log("[QuickSettings] Escape pressed — closing panel");
            panel.visible = false;
        }

        // ── Panel card ────────────────────────────────────────────────────────
        Rectangle {
            id: panelCard

            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
            }
            implicitHeight: cardLayout.implicitHeight + Globals.spacingLoose * 2

            // Card sits flush with top edge (drops directly from the bar)
            // Rounded only on the bottom corners
            radius: Globals.radiusLarge

            color:        Globals.colorBackground
            border.color: Globals.colorBorder
            border.width: 1

            // ── Slide-in animation when panel becomes visible ─────────────────
            // Card fades + translates from slightly above its final position.
            opacity: panel.visible ? 1.0 : 0.0
            transform: Translate {
                y: panel.visible ? 0 : -16
            }

            Behavior on opacity {
                NumberAnimation { duration: Globals.animNormal; easing.type: Easing.OutCubic }
            }
            Behavior on transform.y {
                NumberAnimation { duration: Globals.animNormal; easing.type: Easing.OutCubic }
            }

            // ── Main content layout ───────────────────────────────────────────
            ColumnLayout {
                id: cardLayout

                anchors {
                    top:   parent.top
                    left:  parent.left
                    right: parent.right
                    topMargin:   Globals.spacingLoose
                    leftMargin:  Globals.spacingLoose
                    rightMargin: Globals.spacingLoose
                }
                spacing: Globals.spacingRelaxed

                // ── Header row ────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Globals.spacingNormal

                    Text {
                        text:           "  Quick Settings"
                        color:          Globals.colorAccent
                        font.pixelSize: 14
                        font.bold:      true
                        Layout.fillWidth: true
                    }

                    // Close button
                    Rectangle {
                        width:  24
                        height: 24
                        radius: 6
                        color:  closeBtn.containsMouse ? Globals.colorSurfaceRaised : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Globals.animFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text:             "󰅖"
                            color:            closeBtn.containsMouse ? Globals.colorError : Globals.colorTextDim
                            font.pixelSize:   14

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }
                        }

                        MouseArea {
                            id: closeBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                console.log("[QuickSettings] close button clicked");
                                panel.visible = false;
                            }
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color:  Globals.colorBorder
                }

                // ── Volume section ────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Globals.spacingTight

                    // Label row: icon + "Volume" + current percent
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Globals.spacingNormal

                        Text {
                            text: {
                                if (root.volumeLevel === 0)  return "󰝟"  // muted
                                if (root.volumeLevel < 33)   return "󰕿"  // low
                                if (root.volumeLevel < 67)   return "󰖀"  // mid
                                return "󰕾"                               // high
                            }
                            color:          Globals.blue
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text:           "Volume"
                            color:          Globals.colorText
                            font.pixelSize: 13
                            font.bold:      true
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text:           root.volumeLevel + "%"
                            color:          Globals.colorTextDim
                            font.pixelSize: 12
                            font.family:    "monospace"
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on text {
                                // No animation — text changes instantly
                            }
                        }
                    }

                    // Volume slider
                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true

                        from:       0
                        to:         100
                        stepSize:   1
                        value:      root.volumeLevel

                        // ── CRITICAL: onMoved only, never onValueChanged ───────
                        // onValueChanged would fire when root.volumeLevel is updated
                        // from the poll result, creating an infinite write loop.
                        // onMoved fires ONLY when the user physically drags/clicks.
                        onMoved: {
                            console.log("[QuickSettings] volumeSlider moved → " + value);
                            root.applyVolume(value);
                        }

                        // ── Catppuccin Mocha styled track + handle ─────────────
                        background: Rectangle {
                            x:      volumeSlider.leftPadding
                            y:      volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width:  volumeSlider.availableWidth
                            height: 6
                            radius: 3
                            color:  Globals.colorSurface

                            Rectangle {
                                width:  volumeSlider.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color:  Globals.blue

                                Behavior on width {
                                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        handle: Rectangle {
                            x:      volumeSlider.leftPadding
                                    + volumeSlider.visualPosition
                                    * (volumeSlider.availableWidth - width)
                            y:      volumeSlider.topPadding
                                    + volumeSlider.availableHeight / 2 - height / 2
                            width:  18
                            height: 18
                            radius: 9
                            color:  volumeSlider.pressed ? Globals.colorAccentAlt : Globals.blue
                            border.color: Globals.colorBorderFocus
                            border.width: volumeSlider.pressed ? 2 : 1

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }
                            Behavior on border.width {
                                NumberAnimation { duration: Globals.animFast }
                            }
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color:  Globals.colorBorder
                }

                // ── Brightness section ────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Globals.spacingTight

                    // Label row: icon + "Brightness" + current percent
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Globals.spacingNormal

                        Text {
                            text: {
                                if (root.brightnessLevel < 20) return "󰃞"  // dim
                                if (root.brightnessLevel < 60) return "󰃟"  // medium
                                return "󰃠"                                  // bright
                            }
                            color:          Globals.yellow
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text:           "Brightness"
                            color:          Globals.colorText
                            font.pixelSize: 13
                            font.bold:      true
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text:           root.brightnessLevel + "%"
                            color:          Globals.colorTextDim
                            font.pixelSize: 12
                            font.family:    "monospace"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Brightness slider
                    Slider {
                        id: brightnessSlider
                        Layout.fillWidth: true

                        from:       1     // Never allow 0 — black screen
                        to:         100
                        stepSize:   1
                        value:      root.brightnessLevel

                        // ── CRITICAL: onMoved only, never onValueChanged ───────
                        onMoved: {
                            console.log("[QuickSettings] brightnessSlider moved → " + value);
                            root.applyBrightness(value);
                        }

                        // ── Catppuccin Mocha styled track + handle ─────────────
                        background: Rectangle {
                            x:      brightnessSlider.leftPadding
                            y:      brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                            width:  brightnessSlider.availableWidth
                            height: 6
                            radius: 3
                            color:  Globals.colorSurface

                            Rectangle {
                                width:  brightnessSlider.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color:  Globals.yellow

                                Behavior on width {
                                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        handle: Rectangle {
                            x:      brightnessSlider.leftPadding
                                    + brightnessSlider.visualPosition
                                    * (brightnessSlider.availableWidth - width)
                            y:      brightnessSlider.topPadding
                                    + brightnessSlider.availableHeight / 2 - height / 2
                            width:  18
                            height: 18
                            radius: 9
                            color:  brightnessSlider.pressed ? Globals.peach : Globals.yellow
                            border.color: Globals.yellow
                            border.width: brightnessSlider.pressed ? 2 : 1

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }
                            Behavior on border.width {
                                NumberAnimation { duration: Globals.animFast }
                            }
                        }
                    }
                }

                // ── Bottom spacer (provides visual breathing room) ────────────
                Item { height: Globals.spacingTight }
            }
        }
    }
}
