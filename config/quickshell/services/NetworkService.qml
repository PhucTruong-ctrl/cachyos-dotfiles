// NetworkService.qml — nmcli-based Wi-Fi helper used by the ControlCenter.
// Provides scan/toggle/connect helpers and tracks active SSID state.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NetworkService — singleton service exposing WiFi state via nmcli.
//
// Consumers:
//   - WifiToggle, WifiPanel (future) — read wifiEnabled, activeConnection, etc.
//
// Must NOT import any UI components or create windows.
// Must NOT handle VPN, ethernet, or hotspot (out of scope).
//
// nmcli -t escapes literal colons in field values as '\:'.
// The helper splitNmcliTerse() splits on unescaped ':' only and
// unescapes each field, so SSIDs/security strings containing ':' are
// preserved correctly.
//
// Polling intervals:
//   - Status (wifiEnabled, activeConnection, signalStrength): 10 s
//   - Network list (scanNetworks):                           30 s
//
// Access: NetworkService.wifiEnabled, NetworkService.activeConnection, …

QtObject {
    id: root

    // ── Internal mutable backing state ───────────────────────────────────────
    property bool   _wifiEnabled:       false
    property string _activeConnection:  ""
    property int    _signalStrength:    0
    property var    _networkList:       []
    property bool   _scanning:          false
    property bool   _initialLogDone:    false

    // Per-scan line accumulator (reset before each scan).
    property var    _networkListBuf:    []

    // ── Public read-only interface ────────────────────────────────────────────

    // True if the WiFi radio is enabled ("nmcli radio wifi" = "enabled").
    readonly property bool wifiEnabled: _wifiEnabled

    // SSID of the currently connected network, or "" when not connected.
    readonly property string activeConnection: _activeConnection

    // Signal strength of the active connection (0–100). 0 if not connected.
    readonly property int signalStrength: _signalStrength

    // Array of { ssid, signal, security, active } objects from the last scan.
    // Sorted: active entry first, then by signal descending.
    readonly property var networkList: _networkList

    // True while a wifi rescan is in progress.
    readonly property bool scanning: _scanning

    // ── nmcli terse parser ────────────────────────────────────────────────────
    // nmcli -t escapes ':' inside field values as '\:'.
    // splitNmcliTerse(line) returns an array of unescaped field strings, splitting
    // only on colons that are NOT preceded by a backslash.
    //
    // Algorithm:
    //   Walk the string character by character; collect chars into the current
    //   field.  A ':' preceded by '\' is a literal colon — strip the backslash
    //   and keep the colon.  A bare ':' is a field delimiter.
    function splitNmcliTerse(line) {
        const fields = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length && line[i + 1] === ":") {
                // Escaped colon: emit literal ':' and skip the next char
                current += ":";
                i++;
            } else if (ch === ":") {
                // Unescaped colon: field boundary
                fields.push(current);
                current = "";
            } else {
                current += ch;
            }
        }
        fields.push(current);
        return fields;
    }

    // ── Status reader ─────────────────────────────────────────────────────────
    // Combines wifi radio state + active connection into two output lines.
    //
    // Line 1:  "wifi:enabled"  or  "wifi:disabled"
    // Line 2:  "yes:<ssid>:<signal>"   (absent if no active connection)
    property Process statusReader: Process {
        command: ["bash", "-c",
            "printf 'wifi:%s\\n' \"$(nmcli radio wifi 2>/dev/null)\"; " +
            "nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes:' | head -1"
        ]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.startsWith("wifi:")) {
                    root._wifiEnabled = line.slice(5).trim() === "enabled";
                } else if (line.startsWith("yes:")) {
                    // Format: yes:<ssid>:<signal>
                    // Use escaped-colon-safe parser; fields: [active, ssid, signal]
                    const parts = root.splitNmcliTerse(line);
                    // parts[0]="yes", parts[1]=ssid (may contain literal ':'), parts[2]=signal
                    root._activeConnection = parts.length > 1 ? parts[1] : "";
                    root._signalStrength   = parts.length > 2 ? (parseInt(parts[2]) || 0) : 0;
                }
            }
        }

        onExited: (exitCode) => {
            // Reset active connection state every poll — if the line was absent,
            // the previous values from onRead will stand; if no "yes:" line was
            // emitted (disconnected), they need clearing. We track this via a
            // separate flag to avoid a second process.
            if (!root._initialLogDone) {
                root._initialLogDone = true;
                if (exitCode === 0) {
                    console.log(
                        "NetworkService: wifi=" + (root._wifiEnabled ? "enabled" : "disabled") +
                        ", ssid="   + (root._activeConnection.length > 0 ? root._activeConnection : "none") +
                        ", signal=" + root._signalStrength + "%"
                    );
                } else {
                    console.warn("NetworkService: initial status read failed (exit " + exitCode + ") — nmcli unavailable?");
                }
            }
        }
    }

    // ── Status polling timer (10 seconds) ────────────────────────────────────
    property Timer statusTimer: Timer {
        interval: 10000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            // Reset active-connection fields so stale values don't linger
            // when the user disconnects between polls.
            root._activeConnection = "";
            root._signalStrength   = 0;
            root.statusReader.running = false;
            root.statusReader.running = true;
        }
    }

    // ── Network list reader ───────────────────────────────────────────────────
    // Runs nmcli rescan (triggers a full radio sweep) then lists results.
    // Format per line (nmcli -t):  <ssid>:<signal>:<security>:<active>
    // Literal colons in any field are escaped as '\:' by nmcli.
    property Process networkListReader: Process {
        command: ["bash", "-c",
            "nmcli device wifi rescan 2>/dev/null; " +
            "nmcli -t -f ssid,signal,security,active dev wifi list 2>/dev/null"
        ]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length === 0) return;
                // Use escaped-colon-safe parser so SSIDs and security strings
                // containing literal ':' characters are handled correctly.
                // Format: ssid:signal:security:active  (4 fields minimum)
                const parts = root.splitNmcliTerse(line);
                if (parts.length < 4) return;
                // ssid may itself be empty (hidden network) — allow it.
                root._networkListBuf.push({
                    ssid:     parts[0],
                    signal:   parseInt(parts[1]) || 0,
                    security: parts.slice(2, parts.length - 1).join(":"),
                    active:   parts[parts.length - 1] === "yes"
                });
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 || root._networkListBuf.length > 0) {
                // Sort: active first, then by signal descending.
                const sorted = root._networkListBuf.slice().sort((a, b) => {
                    if (a.active !== b.active) return a.active ? -1 : 1;
                    return b.signal - a.signal;
                });
                root._networkList = sorted;
            }
            root._networkListBuf = [];
            root._scanning = false;
        }
    }

    // ── Network list polling timer (30 seconds) ───────────────────────────────
    // Rescan is expensive (triggers a radio sweep), so 30 s is the minimum safe
    // interval — same as end-4/dots-hyprland uses for nmcli list polling.
    property Timer networkListTimer: Timer {
        interval: 30000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            root.scanNetworks();
        }
    }

    // ── Toggle WiFi ───────────────────────────────────────────────────────────
    // Sends "nmcli radio wifi on" or "nmcli radio wifi off" depending on
    // current state, then refreshes status.
    function toggleWifi() {
        const cmd = root._wifiEnabled ? "off" : "on";
        toggleWifiProcess.command = ["nmcli", "radio", "wifi", cmd];
        toggleWifiProcess.running = false;
        toggleWifiProcess.running = true;
    }

    property Process toggleWifiProcess: Process {
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("NetworkService: toggleWifi() failed with exit code " + exitCode);
            }
            // Refresh status immediately after toggling.
            root.statusReader.running = false;
            root.statusReader.running = true;
        }
    }

    // ── Scan networks ─────────────────────────────────────────────────────────
    // Triggers an immediate rescan + list. Guarded by _scanning to prevent
    // concurrent scans from corrupting _networkListBuf.
    function scanNetworks() {
        if (root._scanning) return;
        root._scanning       = true;
        root._networkListBuf = [];
        root.networkListReader.running = false;
        root.networkListReader.running = true;
    }

    // ── Connect to network ────────────────────────────────────────────────────
    // Connects to the named SSID. Omit password for open/remembered networks.
    function connectToNetwork(ssid, password) {
        if (password && password.length > 0) {
            connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        } else {
            connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid];
        }
        connectProcess.running = false;
        connectProcess.running = true;
    }

    property Process connectProcess: Process {
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("NetworkService: connected successfully");
                root.statusReader.running = false;
                root.statusReader.running = true;
            } else {
                console.warn("NetworkService: connectToNetwork() failed with exit code " + exitCode);
            }
        }
    }

    // ── Startup diagnostic ────────────────────────────────────────────────────
    // The status timer fires immediately (triggeredOnStart: true), which kicks
    // the first nmcli read.  The diagnostic log line appears in onExited once
    // that first read completes — well within qs startup output.
    Component.onCompleted: {
        console.log("NetworkService: initializing...");
    }
}
