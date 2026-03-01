// SysBar.qml
// Inline system-monitoring pill widget for Quickshell.
//
// Displays three live metrics as a horizontal RowLayout pill:
//   ● CPU usage %   — derived from /proc/stat delta between two samples
//   ● RAM usage %   — derived from /proc/meminfo MemTotal / MemAvailable
//   ● CPU temp °C   — derived from /sys/class/thermal/thermal_zone0/temp
//
// Polling interval: 2 seconds (minimum allowed per spec — no busier polling).
// All I/O is non-blocking: each metric uses a short-lived Process whose
// StdioCollector.onStreamFinished callback updates the display property.
//
// Click anywhere on the pill → launches `ghostty -e btop` detached.
//
// Usage: drop <SysBar /> inside any parent Item / RowLayout.
//
// CPU Algorithm:
//   /proc/stat line 1:  cpu  user nice system idle iowait irq softirq steal guest guest_nice
//   total_jiffies   = sum of all fields
//   idle_jiffies    = idle + iowait
//   cpu%            = 100 * (1 - (Δidle / Δtotal))   across two samples
//
//   The two-sample approach is handled by a tiny shell one-liner:
//     sh -c 'read -r l1 < /proc/stat; sleep 1; read -r l2 < /proc/stat; echo "$l1|$l2"'
//   This runs asynchronously inside a dedicated Process object.  QML is never
//   blocked — the StdioCollector.onStreamFinished fires when the 1-second sleep
//   and read are complete.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// SysBar is a self-contained Scope — it manages its own processes and timer.
// Instantiate it wherever you need the monitoring pill.
Scope {
    id: sysBarRoot

    // ──────────────────────────────────────────────────────────────────────────
    // Public display properties (updated asynchronously by their Process)
    // ──────────────────────────────────────────────────────────────────────────
    property real cpuPercent:  0.0    // 0–100
    property real ramPercent:  0.0    // 0–100
    property int  tempCelsius: 0      // degrees Celsius

    // ──────────────────────────────────────────────────────────────────────────
    // Derived display strings
    // ──────────────────────────────────────────────────────────────────────────
    readonly property string cpuText:  cpuPercent.toFixed(0) + "%"
    readonly property string ramText:  ramPercent.toFixed(0) + "%"
    readonly property string tempText: tempCelsius + "°C"

    // ──────────────────────────────────────────────────────────────────────────
    // Catppuccin Mocha colour helpers (local — no global import required)
    // ──────────────────────────────────────────────────────────────────────────
    // accent colours by metric
    readonly property color colCpuIcon:  "#cba6f7"   // mauve
    readonly property color colRamIcon:  "#89dceb"   // sky
    readonly property color colTempIcon: "#f38ba8"   // red (warm = high)

    // Threshold-aware text colour for the value
    function cpuColor()  {
        if (cpuPercent  >= 90) return "#f38ba8";   // red
        if (cpuPercent  >= 60) return "#f9e2af";   // yellow
        return "#cdd6f4";                           // text (normal)
    }
    function ramColor()  {
        if (ramPercent  >= 90) return "#f38ba8";
        if (ramPercent  >= 70) return "#f9e2af";
        return "#cdd6f4";
    }
    function tempColor() {
        if (tempCelsius >= 90) return "#f38ba8";
        if (tempCelsius >= 70) return "#f9e2af";
        return "#cdd6f4";
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CPU Process
    // Reads /proc/stat twice (1 s apart) via shell, emits "line1|line2" on stdout.
    // The StdioCollector fires onStreamFinished after the child exits.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: cpuProc

        // Each polling cycle kicks this off via cpuProc.exec(); it self-terminates.
        command: [
            "sh", "-c",
            "l1=$(head -1 /proc/stat); sleep 1; l2=$(head -1 /proc/stat); printf '%s|%s\\n' \"$l1\" \"$l2\""
        ]

        stdout: StdioCollector {
            id: cpuCollector

            onStreamFinished: {
                const raw = this.text.trim();
                if (!raw) return;

                // Split the two snapshots
                const parts = raw.split("|");
                if (parts.length < 2) return;

                // Parse a /proc/stat cpu line:
                //   "cpu  user nice system idle iowait irq softirq steal ..."
                function parseStat(line) {
                    // Strip the leading "cpu" label
                    const fields = line.trim().split(/\s+/).slice(1).map(Number);
                    const user    = fields[0] || 0;
                    const nice    = fields[1] || 0;
                    const system  = fields[2] || 0;
                    const idle    = fields[3] || 0;
                    const iowait  = fields[4] || 0;
                    const irq     = fields[5] || 0;
                    const softirq = fields[6] || 0;
                    const steal   = fields[7] || 0;
                    const total   = user + nice + system + idle + iowait + irq + softirq + steal;
                    const idleAll = idle + iowait;
                    return { total: total, idle: idleAll };
                }

                const s1 = parseStat(parts[0]);
                const s2 = parseStat(parts[1]);

                const deltaTotal = s2.total - s1.total;
                const deltaIdle  = s2.idle  - s1.idle;

                if (deltaTotal <= 0) {
                    console.log("[SysBar] CPU: deltaTotal=0, skipping update");
                    return;
                }

                const pct = 100 * (1 - (deltaIdle / deltaTotal));
                sysBarRoot.cpuPercent = Math.max(0, Math.min(100, pct));
                console.log("[SysBar] CPU: " + sysBarRoot.cpuPercent.toFixed(1) + "%");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // RAM Process
    // Reads /proc/meminfo and parses MemTotal + MemAvailable.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: ramProc

        command: [
            "sh", "-c",
            "grep -E '^Mem(Total|Available):' /proc/meminfo"
        ]

        stdout: StdioCollector {
            id: ramCollector

            onStreamFinished: {
                const raw = this.text.trim();
                if (!raw) return;

                let total = 0;
                let avail = 0;

                // Lines like:  "MemTotal:       20275644 kB"
                raw.split("\n").forEach(line => {
                    const m = line.match(/^(\w+):\s+(\d+)/);
                    if (!m) return;
                    if (m[1] === "MemTotal")     total = parseInt(m[2], 10);
                    if (m[1] === "MemAvailable") avail = parseInt(m[2], 10);
                });

                if (total <= 0) {
                    console.log("[SysBar] RAM: MemTotal=0, skipping update");
                    return;
                }

                sysBarRoot.ramPercent = 100 * (total - avail) / total;
                console.log("[SysBar] RAM: " + sysBarRoot.ramPercent.toFixed(1) + "%");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Temperature Process
    // Reads thermal_zone0/temp (millidegrees → divide by 1000).
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: tempProc

        command: [
            "sh", "-c",
            "cat /sys/class/thermal/thermal_zone0/temp"
        ]

        stdout: StdioCollector {
            id: tempCollector

            onStreamFinished: {
                const raw = this.text.trim();
                if (!raw) return;

                const millideg = parseInt(raw, 10);
                if (isNaN(millideg)) {
                    console.log("[SysBar] Temp: parse failed, raw='" + raw + "'");
                    return;
                }

                sysBarRoot.tempCelsius = Math.round(millideg / 1000);
                console.log("[SysBar] Temp: " + sysBarRoot.tempCelsius + "°C");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Fire-and-forget Process for launching btop in Ghostty
    // startDetached() ensures the terminal outlives Quickshell if it reloads.
    // ──────────────────────────────────────────────────────────────────────────
    Process {
        id: btopProc
        command: ["ghostty", "-e", "btop"]
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Polling timer — fires every 2 s and (re-)starts all three processes.
    // Running all three in parallel is fine: each is a tiny read-and-exit child.
    // CPU takes ~1 s to finish (it sleeps); RAM and Temp finish in milliseconds.
    // ──────────────────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval:  2000        // 2 second polling cadence (minimum per spec)
        running:   true
        repeat:    true
        triggeredOnStart: true  // fire immediately on startup for fast first read

        onTriggered: {
            // Only start a new CPU process if the previous one has finished,
            // preventing overlapping 1-second sleep processes when the host is slow.
            if (!cpuProc.running) {
                cpuProc.running = true;
            }
            // RAM and Temp are near-instant; safe to restart every cycle.
            ramProc.running = true;
            tempProc.running = true;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Visual: horizontal pill containing three metric items
    // ──────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: pill

        // Intrinsic size: wide enough for the three metrics + separators
        implicitWidth:  pillRow.implicitWidth  + 20
        implicitHeight: 26

        radius: 13              // fully rounded pill
        color:  "#181825"       // Catppuccin Mocha mantle

        border.color: hoverArea.containsMouse ? "#313244" : "transparent"
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        // ── Click to open btop ─────────────────────────────────────────────────
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor

            onClicked: {
                console.log("[SysBar] pill clicked — launching ghostty -e btop");
                btopProc.startDetached();
            }
        }

        // ── Metrics row ────────────────────────────────────────────────────────
        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            // ── CPU ────────────────────────────────────────────────────────────
            RowLayout {
                spacing: 4

                Text {
                    text:           ""           // Nerd Font CPU / chip icon
                    color:          sysBarRoot.colCpuIcon
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: cpuLabel
                    text:           sysBarRoot.cpuText
                    color:          sysBarRoot.cpuColor()
                    font.pixelSize: 12
                    font.family:    "monospace"
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
            }

            // ── Separator ──────────────────────────────────────────────────────
            Rectangle {
                width:  1
                height: 14
                color:  "#313244"   // surface0
                Layout.alignment: Qt.AlignVCenter
            }

            // ── RAM ────────────────────────────────────────────────────────────
            RowLayout {
                spacing: 4

                Text {
                    text:           "󰍛"          // Nerd Font memory icon
                    color:          sysBarRoot.colRamIcon
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: ramLabel
                    text:           sysBarRoot.ramText
                    color:          sysBarRoot.ramColor()
                    font.pixelSize: 12
                    font.family:    "monospace"
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
            }

            // ── Separator ──────────────────────────────────────────────────────
            Rectangle {
                width:  1
                height: 14
                color:  "#313244"
                Layout.alignment: Qt.AlignVCenter
            }

            // ── Temperature ────────────────────────────────────────────────────
            RowLayout {
                spacing: 4

                Text {
                    text:           ""           // Nerd Font thermometer icon
                    color:          sysBarRoot.colTempIcon
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: tempLabel
                    text:           sysBarRoot.tempText
                    color:          sysBarRoot.tempColor()
                    font.pixelSize: 12
                    font.family:    "monospace"
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
            }
        }
    }
}
