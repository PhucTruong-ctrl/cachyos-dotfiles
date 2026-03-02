pragma Singleton
import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    // System Status
    property double cpuUsage: 0.0
    property double cpuTemp: 0.0
    property double ramUsage: 0.0

    // Fetch CPU Usage
    // Note: Quickshell Process executes standard commands.
    Process {
        id: cpuProcess
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}' || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                console.log("CPU returned: " + data);
                let val = parseFloat(data);
                if (!isNaN(val)) root.cpuUsage = val;
            }
        }
    }

    // Fetch RAM Usage
    Process {
        id: ramProcess
        command: ["bash", "-c", "free -m | awk '/Mem:/ {print $3/$2 * 100}' || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                console.log("RAM returned: " + data);
                let val = parseFloat(data);
                if (!isNaN(val)) root.ramUsage = val;
            }
        }
    }

    // Fetch CPU Temp
    Process {
        id: tempProcess
        command: ["bash", "-c", "sensors | grep -E 'Package id 0|Core 0|Tctl' | head -n 1 | grep -oE '\\+[0-9.]+' | head -n 1 | tr -d '+' || acpi -t | awk '{print $4}' | head -n 1"]
        stdout: SplitParser {
            onRead: data => {
                console.log("Temp returned: " + data);
                let val = parseFloat(data);
                if (!isNaN(val)) root.cpuTemp = val;
            }
        }
    }

    Timer {
        id: perfTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProcess.running = true;
            ramProcess.running = true;
            tempProcess.running = true;
        }
    }
}
