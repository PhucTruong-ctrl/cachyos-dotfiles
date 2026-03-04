// Notifs.qml
// Desktop notification daemon overlay for Quickshell.
// Replaces mako/dunst — registers as the org.freedesktop.Notifications D-Bus service.
//
// Behaviour:
//   - NotificationServer receives incoming notifications and marks them as tracked.
//   - A PanelWindow anchored to the top-right corner renders a live ListView of
//     the currently tracked notifications in a stacked card layout.
//   - Each notification auto-dismisses after its expireTimeout (or 5 s fallback).
//   - Clicking the × button dismisses manually.
//   - Urgent (critical) notifications use a red accent; normal and low urgency
//     use the standard Catppuccin Mocha palette.
//   - The window is hidden (zero height) when no notifications are active so it
//     does not reserve any space in the compositor.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../services"

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // Notification server
    // Quickshell registers this on org.freedesktop.Notifications automatically.
    // ──────────────────────────────────────────────────────────────────────────
    NotificationServer {
        id: server

        // Advertise capabilities so apps send full data
        bodySupported:    true
        actionsSupported: true
        imageSupported:   true

        // Keep notifications across quickshell reloads (watchFiles triggers this)
        keepOnReload: true

        // Called for every incoming notification
        onNotification: notif => {
            console.log("[Notifs] incoming notification: app=" + (notif.appName ?? "(unknown)") +
                " summary=" + (notif.summary ?? "") +
                " urgency=" + notif.urgency +
                " expireTimeout=" + notif.expireTimeout);

            // Add notification to persistent store for the Dashboard
            NotifStore.addNotification({
                appName: notif.appName ?? "(unknown)",
                appIcon: notif.appIcon ?? "",
                summary: notif.summary ?? "",
                body: notif.body ?? "",
                urgency: notif.urgency,
                timestamp: Date.now()
            });

            // Track the notification so it lands in trackedNotifications
            notif.tracked = true;

            // Determine display timeout:
            //   expireTimeout > 0 → use it (it's already in seconds per the API)
            //   expireTimeout <= 0 → fall back to 5 s, unless urgency is critical
            const timeoutSecs = notif.expireTimeout > 0
                ? notif.expireTimeout
                : (notif.urgency === NotificationUrgency.Critical ? 0 : 5);

            if (timeoutSecs > 0) {
                console.log("[Notifs] scheduling auto-dismiss in " + timeoutSecs + "s");
                expireTimer.createForNotif(notif, timeoutSecs * 1000);
            } else {
                console.log("[Notifs] critical notification — persists until manually dismissed");
            }
            // Critical notifications with timeout 0 persist until dismissed by user
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Per-notification expire timer factory
    // We create one Qt.createQmlObject Timer per notification so timeouts are
    // independent.  On trigger the notification is expired (hints to the app it
    // timed out) and removed from the tracked list automatically.
    //
    // Guard: if the notification was already dismissed before the timer fires
    // (tracked becomes false), skip the expire call to avoid an invalid/
    // double-expire path.
    // ──────────────────────────────────────────────────────────────────────────
    QtObject {
        id: expireTimer

        function createForNotif(notif, ms) {
            const timerQml = `
                import QtQuick
                Timer {
                    interval: ${ms}
                    running: true
                    repeat: false
                    onTriggered: {
                        // Only expire if the notification is still tracked
                        // (i.e. not yet dismissed manually by the user).
                        if (notifRef.tracked) {
                            notifRef.expire();
                        }
                        destroy();
                    }
                    property var notifRef
                }
            `;
            const t = Qt.createQmlObject(timerQml, root, "expireTimer");
            t.notifRef = notif;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Notification popup window — top-right corner, no exclusive zone
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: notifsWindow

        // Anchor to the top-right corner of the primary screen
        anchors {
            top:   true
            right: true
        }

        // Width of the notification stack; height driven by content
        implicitWidth:  380
        implicitHeight: notifsList.contentHeight > 0
                        ? Math.min(notifsList.contentHeight + 8, 600)
                        : 0

        // Transparent background; cards paint their own backgrounds
        color: "transparent"

        // Do NOT push the bar (or other windows) away — notifications float
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer:     WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"

        // No keyboard focus — notifications must not steal input
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // ── Notifications list ────────────────────────────────────────────────
        ListView {
            id: notifsList

            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                topMargin: 4
            }

            height: parent.implicitHeight

            // ObjectModel.values gives us the live list of tracked notifications
            model:         server.trackedNotifications.values
            spacing:       6
            clip:          true
            boundsBehavior: Flickable.StopAtBounds

            // Smooth insertion/removal animations
            add: Transition {
                NumberAnimation {
                    properties: "opacity,y"
                    from:       0
                    duration:   Appearance.contentSwitch
                    easing.type: Appearance.standardDecel
                }
            }
            remove: Transition {
                NumberAnimation {
                    property:  "opacity"
                    to:        0
                    duration:  Appearance.popupFade
                    easing.type: Appearance.standardAccel
                }
            }
            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration:   Appearance.contentSwitch
                    easing.type: Appearance.standardDecel
                }
            }

            // ── Notification card delegate ─────────────────────────────────────
            delegate: Rectangle {
                id: card
                required property var modelData

                width:   notifsList.width - 16
                x:       8
                height:  cardContent.implicitHeight + 20
                radius:  12

                // Base background
                color:  "#1e1e2e"    // Catppuccin Mocha base

                // Urgency-aware left-border accent
                readonly property color urgencyColor: {
                    const u = card.modelData.urgency;
                    if (u === NotificationUrgency.Critical) return "#f38ba8"  // red
                    if (u === NotificationUrgency.Low)      return "#6c7086"  // overlay0
                    return "#cba6f7"   // mauve (Normal)
                }

                border.color: card.urgencyColor
                border.width: 1

                // ── Left accent stripe ────────────────────────────────────────
                Rectangle {
                    width:  3
                    height: parent.height - 16
                    radius: 2
                    color:  card.urgencyColor
                    anchors {
                        left:           parent.left
                        leftMargin:     6
                        verticalCenter: parent.verticalCenter
                    }
                }

                // ── Card content ──────────────────────────────────────────────
                ColumnLayout {
                    id: cardContent
                    anchors {
                        top:   parent.top
                        left:  parent.left
                        right: parent.right
                        topMargin:   10
                        leftMargin:  18     // leave space for the accent stripe
                        rightMargin: 10
                        bottomMargin: 10
                    }
                    spacing: 4

                    // ── Header row: [icon] [app name] [close btn] ─────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // App icon (falls back to a bell glyph)
                        Item {
                            width:  22
                            height: 22
                            Layout.alignment: Qt.AlignVCenter

                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(
                                    card.modelData.appIcon ?? "", true
                                )
                                visible: (card.modelData.appIcon ?? "") !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text:    "󰂚"    // Nerd Font bell
                                color:   card.urgencyColor
                                font.pixelSize: 14
                                visible: (card.modelData.appIcon ?? "") === ""
                            }
                        }

                        // App name
                        Text {
                            text:  card.modelData.appName ?? ""
                            color: "#6c7086"    // overlay0 — de-emphasised
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Dismiss (×) button
                        Text {
                            text:  "󰅖"    // Nerd Font close circle
                            color: closeArea.containsMouse ? "#f38ba8" : "#6c7086"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on color {
                                ColorAnimation { duration: Appearance.popupFade }
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    console.log("[Notifs] dismiss clicked: app=" +
                                        (card.modelData.appName ?? "(unknown)") +
                                        " summary=" + (card.modelData.summary ?? ""));
                                    card.modelData.dismiss();
                                }
                            }
                        }
                    }

                    // ── Summary (title) ───────────────────────────────────────
                    Text {
                        text:  card.modelData.summary ?? ""
                        color: "#cdd6f4"    // Catppuccin text
                        font.pixelSize: 13
                        font.bold:      true
                        wrapMode:       Text.WordWrap
                        textFormat:     Text.PlainText
                        Layout.fillWidth: true
                        visible: (card.modelData.summary ?? "") !== ""
                    }

                    // ── Body ─────────────────────────────────────────────────
                    Text {
                        text:  card.modelData.body ?? ""
                        color: "#a6adc8"    // subtext1
                        font.pixelSize: 12
                        wrapMode:       Text.WordWrap
                        textFormat:     Text.PlainText
                        Layout.fillWidth: true
                        visible: (card.modelData.body ?? "") !== ""
                        // Limit long bodies to 4 lines so cards stay compact
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    // ── Actions row (if the app sent action buttons) ───────────
                    Row {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: card.modelData.actions && card.modelData.actions.length > 0

                        Repeater {
                            model: card.modelData.actions ?? []

                            delegate: Rectangle {
                                required property var modelData
                                height: 24
                                width:  actionLabel.implicitWidth + 16
                                radius: 6
                                color:  actionArea.containsMouse ? "#313244" : "#181825"
                                border.color: "#45475a"
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: Appearance.popupFade }
                                }

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text:  modelData.text ?? ""
                                    color: "#cdd6f4"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("[Notifs] action invoked: " +
                                            (modelData.text ?? "(unknown)") +
                                            " on notification: " +
                                            (card.modelData.summary ?? ""));
                                        modelData.invoke();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
