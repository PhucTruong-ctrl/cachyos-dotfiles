pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// BatteryService — polls upower every 30 seconds and exposes battery state.
// Falls back to /sys/class/power_supply/BAT0/ if upower is unavailable.
QtObject {
    id: root

    // ── Exposed properties ────────────────────────────────────────────────────
    /// Battery level as a percentage (0–100).
    readonly property int percentage: _percentage
    /// One of: "charging", "discharging", "fully-charged", "unknown"
    readonly property string state: _state
    /// Human-readable time-to-empty string (empty when charging/full)
    readonly property string timeToEmpty: _timeToEmpty
    /// Human-readable time-to-full string (empty when discharging/full)
    readonly property string timeToFull: _timeToFull
    /// True when battery is below 15%
    readonly property bool isLow: _percentage < 15
    /// True when the charger is connected (charging or fully-charged)
    readonly property bool isCharging: _state === "charging" || _state === "fully-charged"

    // ── Internal mutable backing ──────────────────────────────────────────────
    property int    _percentage:  100
    property string _state:       "unknown"
    property string _timeToEmpty: ""
    property string _timeToFull:  ""

    // ── UPower process ────────────────────────────────────────────────────────
    property Process _upowerProc: Process {
        id: upowerProc
        command: ["upower", "-i", "/org/freedesktop/UPower/devices/battery_BAT0"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim();

                // percentage:          100%
                if (trimmed.startsWith("percentage:")) {
                    const match = trimmed.match(/(\d+)%/);
                    if (match) root._percentage = parseInt(match[1]);
                    return;
                }
                // state:               fully-charged
                if (trimmed.startsWith("state:")) {
                    const val = trimmed.replace("state:", "").trim();
                    root._state = val;
                    return;
                }
                // time to empty:       45 minutes
                if (trimmed.startsWith("time to empty:")) {
                    root._timeToEmpty = trimmed.replace("time to empty:", "").trim();
                    return;
                }
                // time to full:        1.2 hours
                if (trimmed.startsWith("time to full:")) {
                    root._timeToFull = trimmed.replace("time to full:", "").trim();
                    return;
                }
            }
        }

        // If upower exits with non-zero (not installed / no battery path), fall
        // back to reading /sys/ directly via the sysfs process.
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("BatteryService: upower failed (exit " + exitCode + "), using /sys/ fallback");
                sysfsProc.running = false;
                sysfsProc.running = true;
            }
        }
    }

    // ── /sys/ fallback process ────────────────────────────────────────────────
    property Process _sysfsProc: Process {
        id: sysfsProc
        command: [
            "bash", "-c",
            "printf '%s %s' " +
            "\"$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)\" " +
            "\"$(cat /sys/class/power_supply/BAT0/status   2>/dev/null || echo Unknown)\""
        ]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    const pct = parseInt(parts[0]);
                    const st  = parts[1].toLowerCase();
                    if (!isNaN(pct)) root._percentage = pct;
                    if (st === "charging")    root._state = "charging";
                    else if (st === "full")   root._state = "fully-charged";
                    else                      root._state = "discharging";
                }
            }
        }
    }

    // ── Poll timer: every 30 seconds (matching original behavior) ─────────────
    property Timer _pollTimer: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Reset time strings each poll so stale values clear when state changes
            root._timeToEmpty = "";
            root._timeToFull  = "";
            upowerProc.running = false;
            upowerProc.running = true;
        }
    }
}
