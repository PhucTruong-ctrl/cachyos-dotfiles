pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
    property color accent: matugenPrimary
    property color success: green
    property color warning: yellow

    // Useful State Toggles
    property bool caffeineActive: false
    property bool nightModeActive: false

    // System Status
    property bool isBatteryCharging: false
    property int batteryRemaining: 100

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
                        const colors = parsed.colors;
                        console.log("GlobalState: Matugen colors loaded successfully");
                        root.matugenPrimary          = colors.primary          || root.matugenPrimary;
                        root.matugenOnPrimary        = colors.onPrimary        || root.matugenOnPrimary;
                        root.matugenBackground       = colors.background       || root.matugenBackground;
                        root.matugenOnBackground     = colors.onBackground     || root.matugenOnBackground;
                        root.matugenSurface          = colors.surface          || root.matugenSurface;
                        root.matugenOnSurface        = colors.onSurface        || root.matugenOnSurface;
                        root.matugenSurfaceVariant   = colors.surfaceVariant   || root.matugenSurfaceVariant;
                        root.matugenOnSurfaceVariant = colors.onSurfaceVariant || root.matugenOnSurfaceVariant;
                        root.matugenError            = colors.error            || root.matugenError;
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
