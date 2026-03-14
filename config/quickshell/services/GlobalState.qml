// GlobalState.qml — Master state singleton for Matugen colors, toggles, and battery info.
// All components/services read palette + feature flags from here.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Catppuccin Mocha Colors Foundation (defaults)
    property color rosewater: "#f5e0dc"
    property color flamingo: "#f2cdcd"
    property color pink: "#f5c2e7"
    property color mauve: "#cba6f7"
    property color red: "#f38ba8"
    property color maroon: "#eba0ac"
    property color peach: "#fab387"
    property color yellow: "#f9e2af"
    property color green: "#a6e3a1"
    property color teal: "#94e2d5"
    property color sky: "#89dceb"
    property color sapphire: "#74c7ec"
    property color blue: "#89b4fa"
    property color lavender: "#b4befe"
    property color text: "#cdd6f4"
    property color subtext1: "#bac2de"
    property color subtext0: "#a6adc8"
    property color overlay2: "#9399b2"
    property color overlay1: "#7f849c"
    property color overlay0: "#6c7086"
    property color surface2: "#585b70"
    property color surface1: "#45475a"
    property color surface0: "#313244"
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"

    // Matugen dynamically generated colors
    // Default to Mocha foundation if loading fails
    property color matugenPrimary: mauve
    property color matugenOnPrimary: base
    property color matugenBackground: base
    property color matugenOnBackground: text
    property color matugenSurface: surface0
    property color matugenOnSurface: text
    property color matugenSurfaceVariant: surface1
    property color matugenOnSurfaceVariant: text
    property color matugenError: red

    // Functional aliases (bound to dynamic matugen colors)
    // Using readonly property ensures a reactive dynamic binding in QML
    readonly property color accent: matugenPrimary
    readonly property color success: green
    readonly property color warning: yellow

    // Useful State Toggles
    property bool caffeineActive: false
    property bool nightModeActive: false
    property bool dndActive: false
    property bool highPerformanceActive: false

    property var osdEvent: ({
        "type": "",
        "value": 0,
        "icon": "",
        "label": ""
    })

    readonly property color osdBackground: Qt.rgba(surface0.r, surface0.g, surface0.b, Appearance.panelOpacity + Appearance.osdBackgroundBoost)
    readonly property color osdTrack: surface1
    readonly property color osdFill: matugenPrimary
    readonly property color osdText: text
    readonly property color osdIcon: matugenPrimary

    // System Status — forwarding aliases to BatteryService singleton
    // batteryLevel: canonical name for downstream tasks / Task 11 lock screen
    readonly property int  batteryLevel:      BatteryService.percentage
    // Legacy aliases kept so existing Bar.qml bindings continue working
    // without change — Bar will be updated separately in this task.
    readonly property int  batteryRemaining:  BatteryService.percentage
    readonly property bool isBatteryCharging: BatteryService.isCharging

    // Path to matugen colors (kept for reference / future use)
    property string colorsPath: Quickshell.env("HOME") + "/.cache/matugen/colors.json"

    property Process colorReader: Process {
        command: ["bash", "-c", "jq -c . ~/.cache/matugen/colors.json 2>/dev/null || echo '{}'"]
        running: false

        stdout: SplitParser {
            // jq -c outputs compact single-line JSON — no buffering needed
            onRead: data => {
                const raw = data.trim();
                if (raw.length === 0) return;
                try {
                    const parsed = JSON.parse(raw);
                    if (parsed && parsed.colors) {
                        const matugenColors = parsed.colors;
                        console.log("GlobalState: Matugen colors loaded successfully");
                        root.matugenPrimary          = matugenColors.primary          || root.matugenPrimary;
                        root.matugenOnPrimary        = matugenColors.onPrimary        || root.matugenOnPrimary;
                        root.matugenBackground       = matugenColors.background       || root.matugenBackground;
                        root.matugenOnBackground     = matugenColors.onBackground     || root.matugenOnBackground;
                        root.matugenSurface          = matugenColors.surface          || root.matugenSurface;
                        root.matugenOnSurface        = matugenColors.onSurface        || root.matugenOnSurface;
                        root.matugenSurfaceVariant   = matugenColors.surfaceVariant   || root.matugenSurfaceVariant;
                        root.matugenOnSurfaceVariant = matugenColors.onSurfaceVariant || root.matugenOnSurfaceVariant;
                        root.matugenError            = matugenColors.error            || root.matugenError;
                        
                        console.log("GlobalState: New Primary Color ->", root.matugenPrimary);
                    }
                } catch(e) {
                    console.error("GlobalState: Failed to parse matugen colors - " + e);
                    console.error("GlobalState: Raw data was: " + raw);
                }
            }
        }
    }

    function reloadColors() {
        console.log("GlobalState: Reloading colors from Matugen...");
        // Force-restart: stop first so the false→true transition is always detected
        colorReader.running = false;
        colorReader.running = true;
    }

    Component.onCompleted: {
        reloadColors();
    }
}
