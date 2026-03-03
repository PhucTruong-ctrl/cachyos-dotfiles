// CavaService.qml — Live audio visualizer data service
//
// Runs cava as a subprocess with raw ASCII output, parses semicolon-separated
// bar values, and exposes them as a normalized list (0.0–1.0 per bar).
//
// Usage:
//   CavaService.bars     — list of real values, each 0.0–1.0 (barCount entries)
//   CavaService.barCount — configured number of bars (20)
//   CavaService.active   — true when cava is running and sending data
//
// Cava config written to /tmp/qs-cava.conf at startup:
//   bars = 20, raw ASCII output to stdout, semicolon delimiter (ASCII 59),
//   values in range 0–100 (normalized to 0.0–1.0 here).
//
// Automatically restarts cava 3 s after unexpected exit (up to 5 consecutive
// failures without producing any data). If cava is unavailable or repeatedly
// crashes before outputting data, restarting stops to prevent an infinite loop.
// The guard resets each time cava successfully delivers at least one frame.

pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // ── Exposed properties ────────────────────────────────────────────────────
    readonly property int  barCount: 20
    readonly property var  bars:     _bars
    readonly property bool active:   _active

    // ── Internal mutable backing ──────────────────────────────────────────────
    property var  _bars:      []
    property bool _active:    false
    // Counts consecutive exits that happened before any valid frame was parsed.
    // Resets to 0 whenever a good frame arrives. Capped restart attempts at 5.
    property int  _failCount: 0

    // ── Cava subprocess ───────────────────────────────────────────────────────
    // Writes minimal cava config to /tmp/qs-cava.conf then starts cava.
    // Output: one line per frame, values 0-100 separated by semicolons.
    property Process _cavaProc: Process {
        id: cavaProc

        command: [
            "bash", "-c",
            [
                "printf '[general]\\nbars=20\\n[output]\\nmethod=raw\\nraw_target=/dev/stdout\\n",
                "data_format=ascii\\nascii_max_range=100\\nbar_delimiter=59\\nframe_delimiter=10\\n'",
                " > /tmp/qs-cava.conf && exec cava -p /tmp/qs-cava.conf"
            ].join("")
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length === 0) return;

                const parts = line.split(";");
                const normalized = [];
                for (let i = 0; i < parts.length; i++) {
                    const raw = parts[i].trim();
                    if (raw.length === 0) continue;
                    const n = parseInt(raw, 10);
                    normalized.push(isNaN(n) ? 0.0 : Math.max(0.0, Math.min(1.0, n / 100.0)));
                }
                if (normalized.length > 0) {
                    root._bars      = normalized;
                    root._active    = true;
                    root._failCount = 0;  // cava is alive and delivering data — reset guard
                }
            }
        }

        onExited: (exitCode) => {
            root._active = false;
            root._failCount++;
            // Guard: stop restarting after 5 consecutive exits with no valid data.
            // This prevents an infinite loop when cava is not installed or always crashes.
            if (root._failCount <= 5) {
                cavaRestartTimer.start();
            }
            // If _failCount > 5, give up silently. CavaService.active remains false,
            // so consumers (MediaWidget, MediaPane) will display their paused/dim fallbacks.
        }
    }

    // Restart cava 3 s after unexpected exit (e.g. audio device disconnect)
    property Timer _cavaRestartTimer: Timer {
        id: cavaRestartTimer
        interval: 3000
        repeat:   false
        onTriggered: {
            cavaProc.running = false;
            cavaProc.running = true;
        }
    }
}
