pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    property var keybinds: []
    property string parserScriptPath: Qt.resolvedUrl("../scripts/hyprland/get_keybinds.py").toString().replace("file://", "")
    property string keybindConfigPath: Quickshell.env("HOME") + "/.config/hypr/config/keybinds.conf"

    property Process _keybindsProc: Process {
        id: keybindsProc
        command: ["python", root.parserScriptPath, "--path", root.keybindConfigPath]
        running: false

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                const raw = data.trim();
                if (raw.length === 0) {
                    root.keybinds = [];
                    return;
                }

                try {
                    const parsed = JSON.parse(raw);
                    root.keybinds = Array.isArray(parsed) ? parsed : [];
                } catch (e) {
                    console.error("[KeybindsService] Failed to parse keybind JSON: " + e);
                    root.keybinds = [];
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[KeybindsService] Parser exited with code " + exitCode);
                root.keybinds = [];
            }
        }
    }

    property Connections _hyprlandEvents: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.reload();
            }
        }
    }

    function reload() {
        keybindsProc.running = false;
        keybindsProc.running = true;
    }

    Component.onCompleted: {
        reload();
    }
}
