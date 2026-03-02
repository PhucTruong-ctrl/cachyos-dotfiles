// AuthService.qml — PAM authentication singleton for the Quickshell lock screen.
//
// Uses the native Quickshell.Services.Pam (PamContext) for direct PAM integration.
//
// Usage: import "../services" in LockScreen.qml, then use AuthService.*
//
// API:
//   authenticate(password)  — Start a PAM auth attempt
//   lock()                  — Activate the lock screen
//   isLocked   : bool       — Whether the session is locked
//   isAuthenticating : bool — Auth in progress
//   failCount  : int        — Consecutive failures since last lock
//   authSuccess  signal     — Emitted on success
//   authFailed   signal     — Emitted on failure
//
// Must NOT use onStdout — always use stdout: SplitParser { onRead: ... }
// Must NOT log or persist password material.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

QtObject {
    id: root

    // ── Exposed state ─────────────────────────────────────────────────────────

    /// True when the lock screen is active and the session is locked.
    property bool isLocked: false

    /// True while an authentication attempt is in progress.
    property bool isAuthenticating: false

    /// Number of consecutive failed authentication attempts since last lock.
    property int failCount: 0

    // ── Signals ───────────────────────────────────────────────────────────────

    /// Emitted when PAM accepts the supplied password.
    signal authSuccess()

    /// Emitted when PAM rejects the supplied password.
    signal authFailed()

    // ── Native PAM context (Quickshell.Services.Pam) ─────────────────────────
    property PamContext _pam: PamContext {
        id: pamCtx

        // Use the same PAM service as hyprlock
        config: "hyprlock"

        onResponseRequired: {
            // When PAM requests a response, supply the queued password
            // (only if we have one queued from authenticate())
            if (root._queuedPassword.length > 0) {
                pamCtx.respond(root._queuedPassword);
                root._queuedPassword = "";
            }
        }

        onCompleted: result => {
            root.isAuthenticating = false;
            root._queuedPassword  = "";

            // PamResult.Success == 0; import is already handled by the module
            if (result === PamResult.Success) {
                console.log("[AuthService] PAM authentication succeeded");
                root.failCount = 0;
                root.isLocked  = false;
                root.authSuccess();
            } else {
                console.log("[AuthService] PAM authentication failed (result=" + result + ")");
                root.failCount++;
                root.authFailed();
            }
        }

        onError: err => {
            console.warn("[AuthService] PAM error: " + err);
            // completed(PamResult.Error) follows automatically — handled above
        }
    }

    // ── Internal: temporary password store (cleared immediately after use) ───
    // Held only for the brief async window between authenticate() and the
    // first onResponseRequired callback. Cleared right after respond() is called.
    property string _queuedPassword: ""

    // ── Public API ────────────────────────────────────────────────────────────

    /// Start a PAM authentication attempt with the given password.
    /// Emits authSuccess() or authFailed() asynchronously.
    function authenticate(password) {
        if (root.isAuthenticating) {
            console.warn("[AuthService] Auth already in progress — ignoring duplicate call");
            return;
        }

        root._queuedPassword  = password;
        root.isAuthenticating = true;

        if (!pamCtx.start()) {
            // start() returned false — PAM context failed to initialise
            console.error("[AuthService] pamCtx.start() failed");
            root.isAuthenticating = false;
            root._queuedPassword  = "";
            root.failCount++;
            root.authFailed();
        }
    }

    /// Lock the session (activates the lock screen).
    function lock() {
        root.failCount = 0;
        root.isLocked  = true;
    }
}
