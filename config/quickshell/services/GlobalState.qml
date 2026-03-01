pragma Singleton
import QtQuick 2.15

QtObject {
    id: root

    // Theming Colors (Default to Catppuccin Mocha colors)
    property color accent: "#cba6f7" // mauve
    property color base: "#1e1e2e"
    property color surface0: "#313244"

    // Useful State Toggles
    property bool caffeineActive: false
    property bool nightModeActive: false

    // System Status
    property bool isBatteryCharging: false
    property int batteryRemaining: 100

    function reloadColors() {
        console.log("GlobalState: Reloading colors...")
        colorLoader.running = true
    }

    /*
     * Normally this would read from the generated JSON,
     * but we provide a hook or property binding that another component
     * handles. To keep it simple, we use a placeholder or rely on Quickshell's
     * IPC/File helpers if they exist, or a script fetching the theme.
     */
}
