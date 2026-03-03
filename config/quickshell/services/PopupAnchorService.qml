// PopupAnchorService.qml — Shared popup anchor geometry service
//
// Stores the trigger item geometry from the bar so that popup panes can
// position themselves anchored directly below the icon/button that opened them.
//
// Usage:
//   In a bar trigger item (e.g., clock, notification icon):
//     MouseArea {
//         onClicked: {
//             var mapped = mapToItem(null, 0, 0)  // map to global coords
//             PopupAnchorService.setAnchor("calendar", mapped.x, width, parent.Screen.height)
//             PopupStateService.toggleExclusive("calendar")
//         }
//     }
//
//   In the popup pane component:
//     x: PopupAnchorService.popupXFor(contentWidth, Screen.width)
//     y: PopupAnchorService.barY
//
// Coordinate system: all values are in screen pixels, absolute positions.

pragma Singleton
import QtQuick

QtObject {
    id: root

    // ── Current anchor state ──────────────────────────────────────────────────
    // anchorX:      left edge of the trigger item in screen coordinates
    // anchorWidth:  width of the trigger item in screen pixels
    // barY:         bottom edge of the bar (= bar height), popup appears below this
    property real   anchorX:     0
    property real   anchorWidth: 0
    property real   barY:        40    // default: bar exclusiveZone height

    // ── setAnchor — called by bar trigger items before opening a popup ────────
    //
    // id:         string id matching the popup (used by PopupStateService; ignored here)
    // x:          global x position of the trigger item's left edge
    // width:      trigger item width in pixels
    // barBottomY: y coordinate of the bar's bottom edge (usually barHeight)
    function setAnchor(id, x, width, barBottomY) {
        anchorX     = x
        anchorWidth = width
        barY        = barBottomY
    }

    // ── popupXFor — compute clamped popup x so it stays within screen bounds ─
    //
    // panelWidth:  width of the popup panel being positioned
    // screenWidth: total screen width in pixels
    //
    // Strategy: center popup over the trigger item, then clamp so that
    //   left edge ≥ 8px margin and right edge ≤ screenWidth - 8px margin.
    function popupXFor(panelWidth, screenWidth) {
        // Center over trigger: midpoint of trigger - half panel width
        var idealX = anchorX + (anchorWidth / 2) - (panelWidth / 2)
        var margin = 8
        var minX   = margin
        var maxX   = screenWidth - panelWidth - margin
        return Math.max(minX, Math.min(idealX, maxX))
    }
}
