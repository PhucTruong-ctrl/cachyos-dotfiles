// LockScreen.qml — Custom Quickshell lock screen
//
// Full-screen Overlay layer window that handles PAM authentication
// via AuthService (Quickshell.Services.Pam).
//
// IPC:       qs ipc call toggle-lockscreen toggle
// Lock:      qs ipc call toggle-lockscreen lock
// Keybind:   bindd = $mainMod, L, Lock the screen, exec, qs ipc call toggle-lockscreen lock
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer with blur backdrop.
//   - Large clock (H:MM AM/PM), date, and "Hello, Phuc" greeting.
//   - Password field: shake animation on failure, accent border on focus.
//   - Keyboard focus exclusive — Escape/alt cannot dismiss.
//   - Fade-out animation on successful authentication.
//   - All colors sourced from GlobalState (no hardcoded hex).

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services"

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-lockscreen"
    //   qs ipc call toggle-lockscreen toggle   → show/hide
    //   qs ipc call toggle-lockscreen lock     → always show (called on lock event)
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-lockscreen"

        function toggle(): void {
            console.log("[LockScreen] IPC toggle — was: " + lockWindow.visible);
            if (!lockWindow.visible) {
                root.activateLock();
            } else {
                // do NOT allow IPC to dismiss the lock — only auth can do that
                console.log("[LockScreen] IPC toggle: cannot dismiss lock via IPC");
            }
        }

        function lock(): void {
            console.log("[LockScreen] IPC lock — activating lock screen");
            root.activateLock();
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: activate the lock screen
    // ──────────────────────────────────────────────────────────────────────────
    function activateLock() {
        AuthService.lock();
        lockWindow.opacity = 1.0;
        lockWindow.visible = true;
        passwordField.text  = "";
        passwordField.forceActiveFocus();
        errorLabel.visible  = false;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // AuthService connections — respond to success/failure
    // ──────────────────────────────────────────────────────────────────────────
    Connections {
        target: AuthService

        function onAuthSuccess() {
            console.log("[LockScreen] Auth succeeded — fading out");
            fadeOutAnim.start();
        }

        function onAuthFailed() {
            console.log("[LockScreen] Auth failed — shaking password field");
            errorLabel.visible = true;
            shakeAnim.start();
            passwordField.text = "";
            passwordField.forceActiveFocus();
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Timer: keep clock updated every second
    // ──────────────────────────────────────────────────────────────────────────
    Timer {
        id: clockTimer
        interval: 1000
        repeat:   true
        running:  lockWindow.visible
        onTriggered: clockText.text = Qt.formatTime(new Date(), "h:mm")
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: lockWindow

        visible: false

        // Exclusive keyboard focus — no Escape or alt exit possible
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-lockscreen"

        // Span the full screen
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Transparent window base — visual bg painted inside
        color: "transparent"

        // Do not push other windows aside
        exclusionMode: ExclusionMode.Ignore

        // Note: PanelWindow does not expose opacity as a QML property;
        // fade-out is driven by the explicit NumberAnimation below.

        NumberAnimation {
            id: fadeOutAnim
            target:   lockWindow
            property: "opacity"
            from:     1.0
            to:       0.0
            duration: 400
            easing.type: Easing.InQuad
            onFinished: {
                lockWindow.visible = false;
                lockWindow.opacity = 1.0;
                passwordField.text = "";
                errorLabel.visible = false;
            }
        }

        // ── Root Item: Keys must be on a child of PanelWindow ─────────────────
        Item {
            id: lockRoot
            anchors.fill: parent
            focus: true

            // Block Escape from closing the lock screen
            Keys.onEscapePressed: {
                console.log("[LockScreen] Escape pressed — blocked on lock screen");
                // do nothing — cannot dismiss lock with Escape
            }

            // Quick-type: any printable key → focus password field
            Keys.onPressed: event => {
                if (!passwordField.activeFocus &&
                    event.text.length > 0 &&
                    event.key !== Qt.Key_Return &&
                    event.key !== Qt.Key_Enter) {
                    passwordField.forceActiveFocus();
                }
            }

            // ── Full-screen dark + blur backdrop ──────────────────────────────
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(
                    GlobalState.base.r,
                    GlobalState.base.g,
                    GlobalState.base.b,
                    0.92
                )
            }

            // ── Center column layout ──────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                // ── Greeting ──────────────────────────────────────────────────
                Text {
                    id: greetingLabel
                    text: "Hello, Phuc"
                    color: GlobalState.subtext1
                    font.pixelSize: 18
                    font.family: "Sans Serif"
                    Layout.alignment: Qt.AlignHCenter
                    bottomPadding: 8
                }

                // ── Big clock ─────────────────────────────────────────────────
                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "h:mm")
                    color: GlobalState.text
                    font.pixelSize: 96
                    font.bold: true
                    font.family: "Sans Serif"
                    Layout.alignment: Qt.AlignHCenter
                }

                // ── AM/PM indicator ───────────────────────────────────────────
                Text {
                    id: ampmText
                    text: Qt.formatTime(new Date(), "AP")
                    color: GlobalState.subtext0
                    font.pixelSize: 22
                    font.family: "Sans Serif"
                    Layout.alignment: Qt.AlignHCenter
                    bottomPadding: 4

                    // Update with clock
                    Connections {
                        target: clockTimer
                        function onTriggered() {
                            ampmText.text = Qt.formatTime(new Date(), "AP");
                        }
                    }
                }

                // ── Date ──────────────────────────────────────────────────────
                Text {
                    id: dateText
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    color: GlobalState.subtext1
                    font.pixelSize: 16
                    font.family: "Sans Serif"
                    Layout.alignment: Qt.AlignHCenter
                    bottomPadding: 40

                    // Update with clock
                    Connections {
                        target: clockTimer
                        function onTriggered() {
                            dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d");
                        }
                    }
                }

                // ── Password container (input + shake) ────────────────────────
                Item {
                    id: passwordContainer
                    Layout.alignment: Qt.AlignHCenter
                    width:  320
                    height: 52

                    // Shake animation on failure
                    SequentialAnimation {
                        id: shakeAnim
                        property int shakeOffset: 12

                        NumberAnimation {
                            target: passwordContainer; property: "x"
                            from: 0; to: shakeOffset
                            duration: 50; easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: passwordContainer; property: "x"
                            from: shakeOffset; to: -shakeOffset
                            duration: 80; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: passwordContainer; property: "x"
                            from: -shakeOffset; to: shakeOffset
                            duration: 80; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: passwordContainer; property: "x"
                            from: shakeOffset; to: -shakeOffset
                            duration: 80; easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: passwordContainer; property: "x"
                            from: -shakeOffset; to: 0
                            duration: 50; easing.type: Easing.OutQuad
                        }
                    }

                    // Password input background
                    Rectangle {
                        id: inputBg
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(
                            GlobalState.surface0.r,
                            GlobalState.surface0.g,
                            GlobalState.surface0.b,
                            0.9
                        )
                        // Accent border on focus, error color on failure
                        border.color: {
                            if (AuthService.failCount > 0 && errorLabel.visible)
                                return GlobalState.red;
                            if (passwordField.activeFocus)
                                return GlobalState.accent;
                            return GlobalState.surface1;
                        }
                        border.width: passwordField.activeFocus ? 2 : 1

                        Behavior on border.color {
                            ColorAnimation { duration: Appearance.popupFade }
                        }
                        Behavior on border.width {
                            NumberAnimation { duration: Appearance.popupFade }
                        }
                    }

                    // Lock icon inside input
                    Text {
                        id: lockIcon
                        anchors {
                            left:           parent.left
                            leftMargin:     16
                            verticalCenter: parent.verticalCenter
                        }
                        text: AuthService.isAuthenticating ? "󰔟" : "󰌾"
                        color: passwordField.activeFocus ? GlobalState.accent : GlobalState.overlay1
                        font.pixelSize: 18

                        Behavior on color {
                            ColorAnimation { duration: Appearance.popupFade }
                        }
                    }

                    // The actual password TextInput
                    TextInput {
                        id: passwordField
                        anchors {
                            left:           lockIcon.right
                            leftMargin:     10
                            right:          parent.right
                            rightMargin:    16
                            verticalCenter: parent.verticalCenter
                        }
                        echoMode:      TextInput.Password
                        color:         GlobalState.text
                        font.pixelSize: 16
                        font.family:   "Sans Serif"
                        passwordCharacter: "•"
                        enabled: !AuthService.isAuthenticating

                        // Submit on Enter
                        Keys.onReturnPressed:  root.submitPassword()
                        Keys.onEnterPressed:   root.submitPassword()

                        // Block Escape from propagating up (lock stays on screen)
                        Keys.onEscapePressed: {
                            console.log("[LockScreen] Escape in TextInput — blocked");
                        }
                    }
                }

                // ── Error / hint label ────────────────────────────────────────
                Text {
                    id: errorLabel
                    text:    AuthService.isAuthenticating ? "Verifying…" : "Wrong password. Try again."
                    color:   AuthService.isAuthenticating ? GlobalState.subtext0 : GlobalState.red
                    font.pixelSize: 13
                    font.family:   "Sans Serif"
                    visible: false
                    Layout.alignment: Qt.AlignHCenter
                    topPadding: 10
                }
            } // end ColumnLayout

            // ── Battery indicator (bottom-right corner) ───────────────────────
            Text {
                id: batteryLabel
                anchors {
                    bottom:       parent.bottom
                    right:        parent.right
                    margins:      24
                }
                text: {
                    var icon = GlobalState.isBatteryCharging ? "󰂄" : "󰁹";
                    return icon + " " + GlobalState.batteryLevel + "%";
                }
                color: GlobalState.subtext0
                font.pixelSize: 14
                font.family: "Sans Serif"
                visible: GlobalState.batteryLevel > 0
            }
        } // end Item lockRoot
    }

    // ──────────────────────────────────────────────────────────────────────────
    // submitPassword: called when user presses Enter
    // ──────────────────────────────────────────────────────────────────────────
    function submitPassword() {
        var pw = passwordField.text;
        if (pw.length === 0) return;
        if (AuthService.isAuthenticating) return;

        console.log("[LockScreen] Submitting authentication attempt");
        errorLabel.visible = false;
        AuthService.authenticate(pw);
    }
}
