// Appearance.qml — Centralized appearance & animation constants
//
// Usage: import "../services" in any component, then reference Appearance.*
//
// Centralizes:
//   - Animation durations (panelSlide, popupFade, contentSwitch)
//   - Easing curves (standardDecel, standardAccel)
//   - Panel corner radius (panelRadius)
//   - Common opacity values (panelOpacity, backdropOpacity)
//
// Must NOT duplicate GlobalState.qml color properties.

pragma Singleton
import QtQuick

QtObject {
    id: root

    // ── Animation durations (ms) ──────────────────────────────────────────────
    readonly property int panelSlide:     250   // slide-in panels (ControlCenter, etc.)
    readonly property int popupFade:      150   // quick fade for popups, border/color transitions
    readonly property int contentSwitch:  200   // content transitions, slide-out, enter/exit animations
    readonly property int osdHideDelay:   1500

    // ── Easing curves ─────────────────────────────────────────────────────────
    readonly property int standardDecel: Easing.OutExpo   // slide-in, decelerate into view
    readonly property int standardAccel: Easing.InExpo    // slide-out, accelerate out of view

    // ── Panel corner radius ───────────────────────────────────────────────────
    readonly property int panelRadius: 12   // major panel containers
    readonly property int osdRadius: 16
    readonly property int osdBarRadius: 4
    readonly property int osdWidth: 320
    readonly property int osdHeight: 64
    readonly property int osdBottomMargin: 80
    readonly property int osdContentMargin: 16
    readonly property int osdContentSpacing: 12
    readonly property int osdIconSize: 24
    readonly property int osdBarHeight: 8
    readonly property int osdValueSize: 14
    readonly property real osdBackgroundBoost: 0.05

    // ── Common opacity values ─────────────────────────────────────────────────
    readonly property real panelOpacity:    0.85   // semi-transparent panel backgrounds
    readonly property real backdropOpacity: 0.3    // dim backdrop overlays

    // ── Bar item interactive styles ───────────────────────────────────────────
    readonly property int barItemRadius:    6    // pill/rounded-rect radius for bar item hover bg
    readonly property int barHoverDuration: 80   // hover enter/exit speed (ms) — fast for snap feel
    readonly property int mediaReveal:      200  // media widget state cross-fade duration (ms)
}
