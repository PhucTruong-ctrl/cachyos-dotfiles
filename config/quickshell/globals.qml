// globals.qml — Catppuccin Mocha palette + application-wide constants
//
// A Quickshell Singleton: no import or qmldir registration required.
// Any neighbouring .qml file can access members directly as:
//   Globals.base          → "#1e1e2e"
//   Globals.mauve         → "#cba6f7"
//   Globals.barHeight     → 40
//
// Reference: https://quickshell.org/docs/master/guide/qml-language/#singletons
// Catppuccin Mocha palette: https://github.com/catppuccin/catppuccin#-palette
//
// NO UI logic, NO window declarations, NO layout code lives here.

pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // Catppuccin Mocha — Base colours
    // Ramp: crust → mantle → base → surface0 → surface1 → surface2
    //       → overlay0 → overlay1 → overlay2
    //       → subtext0 → subtext1 → text
    // ──────────────────────────────────────────────────────────────────────────

    readonly property color crust:    "#11111b"
    readonly property color mantle:   "#181825"
    readonly property color base:     "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay2: "#9399b2"
    readonly property color subtext0: "#a6adc8"
    readonly property color subtext1: "#bac2de"
    readonly property color text:     "#cdd6f4"

    // ──────────────────────────────────────────────────────────────────────────
    // Catppuccin Mocha — Accent colours
    // ──────────────────────────────────────────────────────────────────────────

    readonly property color lavender:  "#b4befe"
    readonly property color blue:      "#89b4fa"
    readonly property color sapphire:  "#74c7ec"
    readonly property color sky:       "#89dceb"
    readonly property color teal:      "#94e2d5"
    readonly property color green:     "#a6e3a1"
    readonly property color yellow:    "#f9e2af"
    readonly property color peach:     "#fab387"
    readonly property color maroon:    "#eba0ac"
    readonly property color red:       "#f38ba8"
    readonly property color mauve:     "#cba6f7"
    readonly property color pink:      "#f5c2e7"
    readonly property color flamingo:  "#f2cdcd"
    readonly property color rosewater: "#f5e0dc"

    // ──────────────────────────────────────────────────────────────────────────
    // Semantic aliases — map palette roles to UI purposes
    // ──────────────────────────────────────────────────────────────────────────

    // Panel / window backgrounds
    readonly property color colorBackground:    base       // main window bg
    readonly property color colorSurface:       surface0   // card / input bg
    readonly property color colorSurfaceRaised: surface1   // hovered / raised card
    readonly property color colorBorder:        surface1   // default border
    readonly property color colorBorderFocus:   mauve      // focused / active border

    // Text hierarchy
    readonly property color colorText:          text       // primary content text
    readonly property color colorTextDim:       subtext0   // secondary / muted text
    readonly property color colorTextDisabled:  overlay0   // placeholder / hint text

    // Accent (interactive elements)
    readonly property color colorAccent:        mauve      // primary accent (buttons, highlights)
    readonly property color colorAccentAlt:     blue       // secondary accent

    // Status colours
    readonly property color colorSuccess:       green
    readonly property color colorWarning:       yellow
    readonly property color colorError:         red
    readonly property color colorInfo:          sky

    // ──────────────────────────────────────────────────────────────────────────
    // Layout constants
    // ──────────────────────────────────────────────────────────────────────────

    readonly property int barHeight:       40    // px — must match exclusiveZone in Bar.qml
    readonly property int radiusSmall:     6     // px — pill / chip corners
    readonly property int radiusMedium:    10    // px — card corners
    readonly property int radiusLarge:     14    // px — overlay / dialog corners
    readonly property int spacingTight:    4     // px
    readonly property int spacingNormal:   8     // px
    readonly property int spacingRelaxed:  12    // px
    readonly property int spacingLoose:    18    // px

    // ──────────────────────────────────────────────────────────────────────────
    // Animation durations (ms)
    // ──────────────────────────────────────────────────────────────────────────

    readonly property int animFast:   100
    readonly property int animNormal: 200
    readonly property int animSlow:   350

    // ──────────────────────────────────────────────────────────────────────────
    // IPC target identifiers
    // Centralised here so component files never hard-code raw strings.
    // ──────────────────────────────────────────────────────────────────────────

    readonly property string ipcToggleLauncher:           "toggle-launcher"
    readonly property string ipcTogglePower:              "toggle-power"
    readonly property string ipcToggleControlCenter:      "toggle-control-center"
    readonly property string ipcToggleNotificationCenter: "toggle-notification-center"
    readonly property string ipcToggleCalendar:           "toggle-calendar"
    readonly property string ipcToggleWallpapers:         "toggle-wallpapers"
}
