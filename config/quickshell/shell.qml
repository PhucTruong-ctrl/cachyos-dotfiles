//@ pragma UseQApplication
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
//
// Services (all pragma Singleton, auto-discovered via `import "services"`):
//   GlobalState.qml        — Catppuccin Mocha + Matugen dynamic colors, state flags
//   Appearance.qml         — Centralized animation durations, easing curves, panel radius
//   NetworkService.qml     — nmcli WiFi wrapper
//   BluetoothService.qml   — bluetoothctl wrapper
//   NotifStore.qml         — Notification persistence
//   Performance.qml        — CPU/RAM/Temp polling
//   MediaService.qml       — Native MPRIS backend (title, artist, controls)
//   PopupAnchorService.qml — Stores trigger geometry (anchorX/anchorWidth/barY) for
//                            icon-anchored popup positioning; exposes popupXFor().
//   PopupStateService.qml  — Single-open popup coordination; openExclusive() /
//                            toggleExclusive() ensure only one popup is open at a time.

import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"   // Loads GlobalState, Appearance, NetworkService, BluetoothService, etc.

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
    // Load ControlCenter here
    //
    // ControlCenter.qml is a slide-down panel anchored top-right.
    // Contains quick toggles, volume/brightness sliders, and
    // expandable WiFi/Bluetooth sub-panels.
    // Toggle via:  qs ipc call control-center toggle
    // Keybind wiring is done in config/hypr/config/keybinds.conf.
    // ------------------------------------------------------------------
    ControlCenter {}

    // ------------------------------------------------------------------
    // Load OSD here
    //
    // OSD.qml is an on-screen display popup for volume and brightness.
    // Automatically appears when volume or brightness changes.
    // ------------------------------------------------------------------
    OSD {}

    // Polkit: using system hyprpolkitagent (started in autostart.conf)
    // No custom QML polkit agent needed.

    // ------------------------------------------------------------------
    // Load ScreenshotTool here
    //
    // ScreenshotTool.qml is a custom screenshot UI integrated into the shell.
    // Includes mode selection (Full/Region/Window) and Save/Copy toggles.
    // Toggle via: qs ipc call toggle-screenshot toggle
    // ------------------------------------------------------------------
    ScreenshotTool {}

    // ------------------------------------------------------------------
    // Load LockScreen here
    //
    // LockScreen.qml is a fullscreen Overlay lock screen with PAM auth.
    // Lock via:   qs ipc call toggle-lockscreen lock
    // Toggle via: qs ipc call toggle-lockscreen toggle
    // Keybind:    Super+L  →  qs ipc call toggle-lockscreen lock
    // The component's own IpcHandler handles visibility internally.
    // Authentication is handled by AuthService (Quickshell.Services.Pam).
    // ------------------------------------------------------------------
    LockScreen {}

    // ------------------------------------------------------------------
    // Load MediaPane here
    //
    // MediaPane.qml is a centered popup panel showing MPRIS media
    // controls — album art, title/artist, play/pause/prev/next.
    // Toggle via:  qs ipc call toggle-media toggle
    // Keybind:     SUPER + M (see config/hypr/config/keybinds.conf)
    // ------------------------------------------------------------------
    MediaPane {}

    // ------------------------------------------------------------------
    // Load Overview here
    //
    // Overview.qml is a fullscreen window-switcher overlay.
    // Shows all open windows grouped by workspace with search/filter.
    // Toggle via: qs ipc call toggle-overview toggle
    // Keybind: SUPER+Tab (wired in config/hypr/config/keybinds.conf)
    // Uses HyprlandService singleton for live hyprctl IPC queries.
    // ------------------------------------------------------------------
    Overview {}

    // ------------------------------------------------------------------
    // Load Cheatsheet here
    //
    // Cheatsheet.qml is a fullscreen keyboard shortcuts overlay sourced
    // from Hyprland bindd descriptions via KeybindsService.
    // Toggle via: qs ipc call toggle-cheatsheet toggle
    // ------------------------------------------------------------------
    Cheatsheet {}

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
