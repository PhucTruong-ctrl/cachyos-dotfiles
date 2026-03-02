// PopupStateService.qml — Single-open popup coordination service
//
// Ensures that only ONE popup pane is open at any time.
// When a second popup is requested, the currently open popup is automatically closed.
//
// Usage:
//   In a bar trigger item:
//     MouseArea {
//         onClicked: {
//             PopupAnchorService.setAnchor("calendar", ...)
//             PopupStateService.toggleExclusive("calendar")
//         }
//     }
//
//   In a popup pane component to reactively open/close:
//     property bool open: PopupStateService.openPopupId === "calendar"
//
// Popup ID registry (must stay in sync with all pane components):
//   "calendar"       — CalendarPane.qml
//   "control-center" — ControlCenter.qml
//   "media"          — MediaPane.qml
//   "notifs"         — NotifPane.qml
//   "theme"          — ThemePane.qml
//   "dashboard"      — Dashboard.qml
//   "launcher"       — Launcher.qml (optional, fullscreen)

pragma Singleton
import QtQuick

QtObject {
    id: root

    // ── Currently open popup ID ───────────────────────────────────────────────
    // Empty string "" means no popup is open.
    property string openPopupId: ""

    // ── openExclusive — open a specific popup, closing any other ─────────────
    //
    // popupId: the id of the popup to open
    //
    // If the popup is already open, this is a no-op (use toggleExclusive to close it).
    function openExclusive(popupId) {
        openPopupId = popupId
    }

    // ── toggleExclusive — toggle a popup, ensuring single-open invariant ─────
    //
    // popupId: the id of the popup to toggle
    //
    // If this popup is currently open → close it (set openPopupId = "").
    // If another popup is open → close it and open this one instead.
    // If no popup is open → open this one.
    function toggleExclusive(popupId) {
        if (openPopupId === popupId) {
            openPopupId = ""
        } else {
            openPopupId = popupId
        }
    }

    // ── closeAll — close any currently open popup ─────────────────────────────
    function closeAll() {
        openPopupId = ""
    }
}
