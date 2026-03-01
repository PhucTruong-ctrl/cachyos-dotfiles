// shell.qml — Quickshell master entry point
//
// Executed by Quickshell on startup:
//   quickshell -p ~/.config/quickshell/shell.qml
//
// Responsibilities (strict — no UI layout logic lives here):
//   1. Shell-level settings (watchFiles)
//   2. Global singleton imports (Globals palette + constants)
//   3. Top-level IPC handlers that orchestrate cross-component visibility
//   4. Instantiate each component module — each module owns its own
//      PanelWindow(s), IpcHandler, and internal layout
//
// Multi-monitor strategy:
//   The Bar component internally uses:
//     Variants { model: Quickshell.screens }
//   so it creates one PanelWindow per connected screen automatically.
//   Overlay components (Launcher, Power, ControlCenter, NotificationCenter)
//   are single-screen overlays that appear on whichever screen has focus —
//   this is the correct UX for popup panels on Wayland/Hyprland.
//
// IPC surface (invoke via `qs ipc call <target> <function>`):
//   toggle-launcher           → toggle   — App launcher overlay
//   toggle-power              → toggle   — Power menu overlay
//   toggle-control-center     → toggle   — Quick-settings + sliders panel
//   toggle-notification-center → toggle  — Notification history panel
//   toggle-calendar           → toggle   — Calendar popup
//
// Component map (all files under components/):
//   Bar.qml                — Status bar  (top panel, one window per monitor)
//   Notifs.qml             — Live notification daemon (freedesktop D-Bus)
//   Power.qml              — Power menu overlay
//   Launcher.qml           — Application launcher overlay
//   QuickSettings.qml      — Volume / brightness / WiFi sliders + toggles
//   SysBar.qml             — CPU / RAM / Temp indicators (inline in Bar)
//   CalendarPane.qml       — Month calendar popup
//   ControlCenter.qml      — Wallpaper grid + matugen integration
//   NotificationCenter.qml — Notification history center

import QtQuick
import Quickshell
import "components"

ShellRoot {
    // ──────────────────────────────────────────────────────────────────────────
    // Shell-level settings
    // ──────────────────────────────────────────────────────────────────────────

    settings {
        // Reload the shell automatically whenever any .qml source file is saved.
        watchFiles: true
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Status Bar
    //
    // Bar.qml uses Variants { model: Quickshell.screens } internally to spawn
    // one PanelWindow per monitor. It handles hotplug automatically.
    // Do NOT wrap it in another Variants here — Bar owns its own screen loop.
    // ──────────────────────────────────────────────────────────────────────────

    Bar {}

    // ──────────────────────────────────────────────────────────────────────────
    // Notification Daemon
    //
    // Registers on org.freedesktop.Notifications (replaces mako/dunst).
    // Must start immediately so no notifications are lost at shell startup.
    // ──────────────────────────────────────────────────────────────────────────

    Notifs {}

    // ──────────────────────────────────────────────────────────────────────────
    // Power Menu
    //
    // Hidden by default. Toggle via:  qs ipc call toggle-power toggle
    // ──────────────────────────────────────────────────────────────────────────

    Power {}

    // ──────────────────────────────────────────────────────────────────────────
    // Application Launcher
    //
    // Hidden by default. Toggle via:  qs ipc call toggle-launcher toggle
    // ──────────────────────────────────────────────────────────────────────────

    Launcher {}

    // ──────────────────────────────────────────────────────────────────────────
    // Quick Settings Panel  (Task 3 + Task 4)
    //
    // Slide-in panel with volume / brightness sliders and action toggles
    // (Night Mode, Game Mode, Caffeine).
    // Hidden by default. Toggle via:  qs ipc call toggle-control-center toggle
    //                            or:  qs ipc call toggle-quicksettings toggle
    // ──────────────────────────────────────────────────────────────────────────

    QuickSettings {}

    // ──────────────────────────────────────────────────────────────────────────
    // Calendar Pane  (Task 5)
    //
    // Month-view popup anchored below the clock in the bar.
    // Hidden by default. Toggle via:  qs ipc call toggle-calendar toggle
    //
    // Uncomment once CalendarPane.qml is implemented:
    // CalendarPane {}
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // Wallpaper Control Center  (Task 6)
    //
    // Fullscreen overlay grid of ~/Wallpaper images; applies via swww + matugen.
    // Part of toggle-control-center IPC surface.
    //
    // Uncomment once ControlCenter.qml is implemented:
    // ControlCenter {}
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // Notification Center  (Task 7)
    //
    // Slide-in panel showing notification history; clears on request.
    // Hidden by default. Toggle via:  qs ipc call toggle-notification-center toggle
    //
    // Uncomment once NotificationCenter.qml is implemented:
    // NotificationCenter {}
    // ──────────────────────────────────────────────────────────────────────────
}
