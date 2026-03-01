pragma Singleton
import QtQuick 2.15
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    
    // System Status
    property double cpuUsage: 0.0
    property double cpuTemp: 0.0
    property double ramUsage: 0.0

    // Fetch CPU Usage
    // Note: Quickshell Process executes standard commands.
    Process {
        id: cpuProcess
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'"]
        stdout: function(output) {
            root.cpuUsage = parseFloat(output) || 0.0;
        }
    }

    // Fetch RAM Usage
    Process {
        id: ramProcess
        command: ["sh", "-c", "free -m | awk '/Mem:/ {print ($3/$2)*100}'"]
        stdout: function(output) {
            root.ramUsage = parseFloat(output) || 0.0;
        }
    }

    // Fetch CPU Temp
    Process {
        id: tempProcess
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp | awk '{print $1/1000}'"]
        stdout: function(output) {
            root.cpuTemp = parseFloat(output) || 0.0;
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
