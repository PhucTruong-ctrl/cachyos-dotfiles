// CalendarPopup.qml
// Month-view calendar popup anchored to the top-right corner (drops below the clock).
//
// IPC toggle:  qs ipc call toggle-calendar toggle
// Keybind example (hyprland.conf):
//   bind = SUPER, C, exec, qs ipc call toggle-calendar toggle
//
// Design:
//   - PanelWindow anchored top + right, slides in from above on the Overlay layer.
//   - No exclusive zone — floats above all windows.
//   - Month header: previous / next navigation arrows + "Month Year" title.
//   - 7-column grid: Mon Tue Wed Thu Fri Sat Sun header row, then the day cells.
//   - Today's day is highlighted with Globals.colorAccent background.
//   - Days outside the current month are shown dimmed (Globals.colorTextDisabled).
//   - Escape or clicking outside closes the popup.
//   - Uses the JavaScript Date object for all calendar math — no manual leap-year
//     logic required:
//       new Date(year, month, 0).getDate() → last day of previous month
//       new Date(year, month + 1, 0).getDate() → days in current month
//       new Date(year, month, 1).getDay() → weekday of the 1st (0=Sun, 1=Mon…)
//
// MUST NOT: duplicate Waybar, Mako, or any non-Quickshell component.
// MUST NOT: hardcode leap-year logic (Qt Date handles it automatically).

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // State: which month/year is currently displayed
    // Initialised to today's month/year via Component.onCompleted.
    // ──────────────────────────────────────────────────────────────────────────
    property int displayYear:  new Date().getFullYear()
    property int displayMonth: new Date().getMonth()   // 0-based (Jan=0)

    // ──────────────────────────────────────────────────────────────────────────
    // Today's date — used to highlight the current day cell.
    // These are fixed for the lifetime of the component.
    // ──────────────────────────────────────────────────────────────────────────
    readonly property int todayYear:  new Date().getFullYear()
    readonly property int todayMonth: new Date().getMonth()
    readonly property int todayDay:   new Date().getDate()

    // ──────────────────────────────────────────────────────────────────────────
    // Derived: month name for the header
    // ──────────────────────────────────────────────────────────────────────────
    readonly property string monthName: Qt.formatDate(
        new Date(root.displayYear, root.displayMonth, 1),
        "MMMM yyyy"
    )

    // ──────────────────────────────────────────────────────────────────────────
    // Calendar math — all via JS Date so leap years are automatic.
    //
    // cellModel: flat array of 42 cell objects (6 weeks × 7 days) covering
    //            the visible grid, including leading/trailing days from
    //            adjacent months.
    //
    //   { day: <int 1-31>, isCurrentMonth: <bool>, isToday: <bool> }
    //
    // The grid always starts on Monday:
    //   JS getDay() returns 0=Sun…6=Sat, so we remap to 0=Mon…6=Sun:
    //     mondayOffset = (jsDay + 6) % 7
    // ──────────────────────────────────────────────────────────────────────────
    readonly property var cellModel: {
        const y = root.displayYear;
        const m = root.displayMonth;

        // Days in the current month
        const daysInMonth = new Date(y, m + 1, 0).getDate();

        // Days in the previous month (for leading fill)
        const daysInPrevMonth = new Date(y, m, 0).getDate();

        // Weekday of the 1st of the month (Monday-based offset: 0=Mon … 6=Sun)
        const firstJsDay    = new Date(y, m, 1).getDay();   // 0=Sun…6=Sat
        const leadingBlanks = (firstJsDay + 6) % 7;         // shift: Sun→6, Mon→0

        const cells = [];

        // ── Leading days from previous month ─────────────────────────────────
        for (let i = leadingBlanks - 1; i >= 0; i--) {
            cells.push({
                day: daysInPrevMonth - i,
                isCurrentMonth: false,
                isToday: false
            });
        }

        // ── Days of the current month ─────────────────────────────────────────
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({
                day: d,
                isCurrentMonth: true,
                isToday: (d === root.todayDay &&
                          m === root.todayMonth &&
                          y === root.todayYear)
            });
        }

        // ── Trailing days from next month (fill to 42 cells = 6 full rows) ───
        let trailing = 1;
        while (cells.length < 42) {
            cells.push({
                day: trailing++,
                isCurrentMonth: false,
                isToday: false
            });
        }

        return cells;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-calendar"
    // Invoke: qs ipc call toggle-calendar toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-calendar"

        function toggle(): void {
            console.log("[Calendar] IPC toggle called — visible was: " + calWindow.visible);
            if (!calWindow.visible) {
                // Always snap back to today's month when opening
                root.displayYear  = root.todayYear;
                root.displayMonth = root.todayMonth;
            }
            calWindow.visible = !calWindow.visible;
            console.log("[Calendar] visibility is now: " + calWindow.visible);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Panel Window — anchored top-right so it drops directly below the clock
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: calWindow

        // Hidden on startup — IPC or clock click reveals it
        visible: false

        // Sit above all windows; no exclusive zone (we float, not push)
        anchors {
            top:   true
            right: true
        }

        implicitWidth:  calCard.implicitWidth
        implicitHeight: calCard.implicitHeight

        color: "transparent"

        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-calendar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Escape → close
        Keys.onEscapePressed: {
            console.log("[Calendar] Escape pressed — closing");
            calWindow.visible = false;
        }

        // ── Calendar card ─────────────────────────────────────────────────────
        Rectangle {
            id: calCard

            anchors {
                top:   parent.top
                right: parent.right
            }

            implicitWidth:  contentLayout.implicitWidth  + Globals.spacingLoose * 2
            implicitHeight: contentLayout.implicitHeight + Globals.spacingLoose * 2

            radius: Globals.radiusLarge
            color:        Globals.colorBackground
            border.color: Globals.colorBorder
            border.width: 1

            // ── Slide-in animation ────────────────────────────────────────────
            opacity: calWindow.visible ? 1.0 : 0.0
            transform: Translate {
                y: calWindow.visible ? 0 : -12
            }

            Behavior on opacity {
                NumberAnimation {
                    duration:     Globals.animNormal
                    easing.type:  Easing.OutCubic
                }
            }
            Behavior on transform.y {
                NumberAnimation {
                    duration:     Globals.animNormal
                    easing.type:  Easing.OutCubic
                }
            }

            // ── Swallow clicks so they don't propagate to any backdrop ────────
            MouseArea {
                anchors.fill: parent
                onClicked: { /* swallow */ }
            }

            // ── Main content ──────────────────────────────────────────────────
            ColumnLayout {
                id: contentLayout

                anchors {
                    top:   parent.top
                    left:  parent.left
                    right: parent.right
                    topMargin:   Globals.spacingLoose
                    leftMargin:  Globals.spacingLoose
                    rightMargin: Globals.spacingLoose
                }

                spacing: Globals.spacingNormal

                // ── Header row: ‹ Month Year › ────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Globals.spacingNormal

                    // ← Previous month button
                    Rectangle {
                        width:  28
                        height: 28
                        radius: Globals.radiusSmall
                        color:  prevBtn.containsMouse
                                ? Globals.colorSurfaceRaised
                                : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Globals.animFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text:  "󰍞"
                            color: prevBtn.containsMouse
                                   ? Globals.colorText
                                   : Globals.colorTextDim
                            font.pixelSize: 14

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }
                        }

                        MouseArea {
                            id: prevBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor

                            onClicked: {
                                console.log("[Calendar] ← clicked — going to previous month");
                                if (root.displayMonth === 0) {
                                    root.displayMonth = 11;
                                    root.displayYear -= 1;
                                } else {
                                    root.displayMonth -= 1;
                                }
                            }
                        }
                    }

                    // Month + Year label (centred, fills remaining space)
                    Text {
                        Layout.fillWidth: true
                        text:              root.monthName
                        color:             Globals.colorAccent
                        font.pixelSize:    14
                        font.bold:         true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // → Next month button
                    Rectangle {
                        width:  28
                        height: 28
                        radius: Globals.radiusSmall
                        color:  nextBtn.containsMouse
                                ? Globals.colorSurfaceRaised
                                : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Globals.animFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text:  "󰍟"
                            color: nextBtn.containsMouse
                                   ? Globals.colorText
                                   : Globals.colorTextDim
                            font.pixelSize: 14

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }
                        }

                        MouseArea {
                            id: nextBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor

                            onClicked: {
                                console.log("[Calendar] → clicked — going to next month");
                                if (root.displayMonth === 11) {
                                    root.displayMonth = 0;
                                    root.displayYear += 1;
                                } else {
                                    root.displayMonth += 1;
                                }
                            }
                        }
                    }
                }

                // ── Thin divider ──────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color:  Globals.colorBorder
                }

                // ── Day-of-week header row: Mon Tue Wed Thu Fri Sat Sun ───────
                GridLayout {
                    id: weekdayHeader
                    Layout.fillWidth: true
                    columns:     7
                    rowSpacing:  0
                    columnSpacing: 0

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        Text {
                            required property string modelData
                            required property int    index

                            Layout.fillWidth: true
                            text:               modelData
                            color:              // Weekend columns (Sa=5, Su=6) slightly dimmer
                                               index >= 5
                                               ? Globals.colorTextDim
                                               : Globals.subtext1
                            font.pixelSize:    11
                            font.bold:         true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // ── Day cells: 6 rows × 7 columns ────────────────────────────
                GridLayout {
                    id: daysGrid
                    Layout.fillWidth: true
                    columns:      7
                    rowSpacing:   2
                    columnSpacing: 2

                    Repeater {
                        model: root.cellModel

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitWidth:  32
                            implicitHeight: 32
                            radius: Globals.radiusSmall

                            // Today → accent background; all others transparent
                            color: modelData.isToday
                                   ? Globals.colorAccent
                                   : (dayHover.containsMouse && modelData.isCurrentMonth
                                      ? Globals.colorSurfaceRaised
                                      : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: Globals.animFast }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day

                                // Colour priority:
                                //   today        → dark base (contrast on accent bg)
                                //   current month → normal text
                                //   other month   → disabled/dim text
                                color: modelData.isToday
                                       ? Globals.colorBackground
                                       : (modelData.isCurrentMonth
                                          ? Globals.colorText
                                          : Globals.colorTextDisabled)

                                font.pixelSize: 12
                                font.bold:      modelData.isToday
                            }

                            // Subtle hover effect for current-month days
                            MouseArea {
                                id: dayHover
                                anchors.fill: parent
                                hoverEnabled: modelData.isCurrentMonth
                                cursorShape:  modelData.isCurrentMonth
                                              ? Qt.PointingHandCursor
                                              : Qt.ArrowCursor

                                onClicked: {
                                    if (modelData.isCurrentMonth) {
                                        console.log("[Calendar] day clicked: "
                                            + root.displayYear + "-"
                                            + (root.displayMonth + 1) + "-"
                                            + modelData.day);
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Bottom spacer ─────────────────────────────────────────────
                Item { height: Globals.spacingTight }
            }
        }
    }
}
