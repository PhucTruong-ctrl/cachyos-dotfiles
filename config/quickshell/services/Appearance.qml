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

    // ── Easing curves ─────────────────────────────────────────────────────────
    readonly property int standardDecel: Easing.OutExpo   // slide-in, decelerate into view
    readonly property int standardAccel: Easing.InExpo    // slide-out, accelerate out of view

    // ── Panel corner radius ───────────────────────────────────────────────────
    readonly property int panelRadius: 12   // major panel containers

    // ── Common opacity values ─────────────────────────────────────────────────
    readonly property real panelOpacity:    0.85   // semi-transparent panel backgrounds
    readonly property real backdropOpacity: 0.3    // dim backdrop overlays

    // ── Bar item interactive styles ───────────────────────────────────────────
    readonly property int barItemRadius:    6    // pill/rounded-rect radius for bar item hover bg
    readonly property int barHoverDuration: 80   // hover enter/exit speed (ms) — fast for snap feel
    readonly property int mediaReveal:      200  // media widget state cross-fade duration (ms)
}
