pragma Singleton
import QtQuick
import Quickshell.Io

// QtObject is the correct root type for a singleton service that has no
// visual presence. Item adds an implicit scene-graph node and geometry
// properties that are wasted overhead for a pure data service.
QtObject {
    id: root

    // System Status
    property double cpuUsage: 0.0
    property double cpuTemp: 0.0
    property double ramUsage: 0.0

    // Fetch CPU Usage
    property Process _cpuProcess: Process {
        id: cpuProcess
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}' || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                const val = parseFloat(data);
                if (!isNaN(val)) root.cpuUsage = val;
            }
        }
    }

    // Fetch RAM Usage
    property Process _ramProcess: Process {
        id: ramProcess
        command: ["bash", "-c", "free -m | awk '/Mem:/ {print $3/$2 * 100}' || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                const val = parseFloat(data);
                if (!isNaN(val)) root.ramUsage = val;
            }
        }
    }

    // Fetch CPU Temp
    property Process _tempProcess: Process {
        id: tempProcess
        command: ["bash", "-c", "sensors | grep -E 'Package id 0|Core 0|Tctl' | head -n 1 | grep -oE '\\+[0-9.]+' | head -n 1 | tr -d '+' || acpi -t | awk '{print $4}' | head -n 1"]
        stdout: SplitParser {
            onRead: data => {
                const val = parseFloat(data);
                if (!isNaN(val)) root.cpuTemp = val;
            }
        }
    }

    property Timer _perfTimer: Timer {
        id: perfTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProcess.running = false;
            cpuProcess.running = true;
            ramProcess.running = false;
            ramProcess.running = true;
            tempProcess.running = false;
            tempProcess.running = true;
        }
    }
}
