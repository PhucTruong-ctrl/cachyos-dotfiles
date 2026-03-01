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
    // Load Dashboard here
    //
    // Dashboard.qml is a massive PanelWindow showing NotifCenter and 
    // Performance metrics, docked to the right edge.
    // Toggle via: qs ipc call toggle-dashboard toggle
    // ------------------------------------------------------------------
    Dashboard {}
}
