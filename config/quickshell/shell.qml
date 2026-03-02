// shell.qml — Quickshell master loader
//
// This file is the single entrypoint executed by Quickshell on startup:
//   quickshell -p ~/.config/quickshell/shell.qml
//
// Responsibilities:
//   1. Declare shell-level settings (watchFiles, etc.)
//   2. Instantiate each component module — no UI layout logic lives here
//   3. Each component manages its own IpcHandler and visibility internally
//
// Component map (all files under components/):
//   Bar.qml      — Status bar (top panel, one PanelWindow per monitor)
//   Notifs.qml   — Notification daemon overlay (org.freedesktop.Notifications)
//   Power.qml    — Power menu overlay (lock / logout / suspend / reboot / shutdown)
//   Launcher.qml — Application launcher (fuzzy, .desktop-file driven)

import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"

ShellRoot {
    // ------------------------------------------------------------------
    // Shell-level settings
    // ------------------------------------------------------------------
    settings {
        // Reload the shell automatically whenever any .qml source file is saved.
        watchFiles: true
    }

    // ------------------------------------------------------------------
    // GlobalState IPC bridge
    //
    // Allows external scripts to force a color reload after matugen writes
    // ~/.cache/matugen/colors.json:
    //   qs ipc call global-state reload-colors
    // ------------------------------------------------------------------
    IpcHandler {
        target: "global-state"
        function reloadColors(): void {
            console.log("[shell] IPC received: global-state reload-colors");
            GlobalState.reloadColors();
        }
    }

    // ------------------------------------------------------------------
    // Load Bar here
    //
    // Bar.qml creates one PanelWindow per connected screen and handles
    // monitor hotplug automatically via Quickshell's Variants helper.
    // ------------------------------------------------------------------
    Bar {}

    // ------------------------------------------------------------------
    // Load Notifs here
    //
    // Notifs.qml registers as the org.freedesktop.Notifications D-Bus
    // service (mako/dunst replacement) and renders ephemeral popup cards
    // in the top-right corner.  Always active — the daemon must start
    // immediately so no notifications are lost at shell startup.
    // ------------------------------------------------------------------
    Notifs {}

    // ------------------------------------------------------------------
    // Load Power here
    //
    // Power.qml is a fullscreen overlay hidden by default.
    // Toggle via:  qs ipc call toggle-power toggle
    // Keybind wiring is done in config/hypr/config/keybinds.conf.
    // The component's own IpcHandler handles visibility internally.
    // ------------------------------------------------------------------
    Power {}

    // ------------------------------------------------------------------
    // Load Launcher here
    //
    // Launcher.qml is a keyboard-driven overlay hidden by default.
    // Toggle via:  qs ipc call toggle-launcher toggle
    // Keybind wiring is done in config/hypr/config/keybinds.conf.
    // The component's own IpcHandler handles visibility internally.
    // ------------------------------------------------------------------
    Launcher {}

    // ------------------------------------------------------------------
    // Load CalendarPane here
    //
    // CalendarPane.qml is a popup housing a MonthGrid and DayOfWeekRow.
    // Toggle via:  qs ipc call toggle-calendar toggle
    // ------------------------------------------------------------------
    CalendarPane {}

    // ------------------------------------------------------------------
    // Load NotifPane here
    //
    // NotifPane.qml is a PanelWindow showing NotifCenter
    // docked to the right edge.
    // Toggle via: qs ipc call toggle-notifs toggle
    // ------------------------------------------------------------------
    NotifPane {}

    // ------------------------------------------------------------------
    // Load ThemePane here
    //
    // ThemePane.qml is a PanelWindow showing ThemeMatrix
    // docked to the right edge.
    // Toggle via: qs ipc call toggle-theme toggle
    // ------------------------------------------------------------------
    ThemePane {}

    // ------------------------------------------------------------------
    // Wallpaper restore on startup
    //
    // Reads the persisted wallpaper path from
    // ~/.cache/quickshell/current_wallpaper and re-applies it via
    // wallpaper-engine.sh (which also re-runs matugen color generation).
    // Runs asynchronously so it never blocks shell startup.
    // ------------------------------------------------------------------
    Process {
        id: wpRestoreReader
        command: ["cat", Quickshell.env("HOME") + "/.cache/quickshell/current_wallpaper"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var savedPath = data.trim();
                if (savedPath.length > 0) {
                    console.log("[shell] Restoring wallpaper:", savedPath);
                    var scriptPath = Qt.resolvedUrl("scripts/wallpaper-engine.sh").toString().replace("file://", "");
                    wpRestoreProcess.command = ["bash", scriptPath, savedPath];
                    wpRestoreProcess.running = true;
                }
            }
        }
    }

    Process {
        id: wpRestoreProcess
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[shell] Wallpaper restored, reloading colors");
                GlobalState.reloadColors();
            }
        }
    }
}
