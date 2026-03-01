// QuickSettings.qml
// Quick settings panel for Volume, Brightness, Night Mode and Caffeine.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    
    color: "transparent"
    implicitHeight: mainCol.implicitHeight
    
    // Process calls for reading/writing volume and brightness
    
    // Volume Control using pamixer
    property int currentVolume: 0
    property bool isMuted: false
    
    Process {
        id: pamixerGetVolume
        command: ["pamixer", "--get-volume"]
        running: true
        onStdout: (data) => {
            const vol = parseInt(data.trim());
            if (!isNaN(vol)) {
                currentVolume = vol;
                if (!volSlider.pressed) {
                    volSlider.value = vol;
                }
            }
        }
    }
    
    Process {
        id: pamixerGetMute
        command: ["pamixer", "--get-mute"]
        running: true
        onStdout: (data) => {
            isMuted = (data.trim() === "true");
        }
    }
    
    Process {
        id: pamixerSetVolume
        property int targetVol: 0
        command: ["pamixer", "--set-volume", targetVol.toString()]
        onExited: {
            pamixerGetVolume.running = true;
        }
    }
    
    Process {
        id: pamixerToggleMute
        command: ["pamixer", "--toggle-mute"]
        onExited: {
            pamixerGetMute.running = true;
        }
    }
    
    // Brightness Control using brightnessctl
    property int currentBrightness: 0
    property int maxBrightness: 100
    
    Process {
        id: brightnessGetMax
        command: ["brightnessctl", "m"]
        running: true
        onStdout: (data) => {
            const max = parseInt(data.trim());
            if (!isNaN(max) && max > 0) {
                maxBrightness = max;
                brightnessGet.running = true; // wait for max to calculate percentage
            }
        }
    }
    
    Process {
        id: brightnessGet
        command: ["brightnessctl", "g"]
        running: false
        onStdout: (data) => {
            const val = parseInt(data.trim());
            if (!isNaN(val) && maxBrightness > 0) {
                const percent = Math.round((val / maxBrightness) * 100);
                currentBrightness = percent;
                if (!brightSlider.pressed) {
                    brightSlider.value = percent;
                }
            }
        }
    }
    
    Process {
        id: brightnessSet
        property int targetPercent: 0
        command: ["brightnessctl", "set", targetPercent.toString() + "%"]
        onExited: {
            brightnessGet.running = true;
        }
    }
    
    // Toggles logic
    
    // Night Mode (wlsunset)
    property bool nightModeActive: false
    
    Process {
        id: wlsunsetCheck
        command: ["pgrep", "-x", "wlsunset"]
        running: true
        onExited: (code) => {
            nightModeActive = (code === 0);
        }
    }
    
    Process {
        id: wlsunsetStart
        command: ["wlsunset", "-t", "4000", "-T", "6500"]
        onExited: {
            wlsunsetCheck.running = true;
        }
    }
    
    Process {
        id: wlsunsetKill
        command: ["pkill", "-x", "wlsunset"]
        onExited: {
            wlsunsetCheck.running = true;
        }
    }
    
    // Caffeine (hypridle inhibitor)
    property bool caffeineActive: false
    
    Process {
        id: caffeineCheck
        command: ["pgrep", "-x", "hypridle"]
        running: true
        onExited: (code) => {
            // If hypridle is NOT running, caffeine is active
            caffeineActive = (code !== 0);
        }
    }
    
    Process {
        id: hypridleStart
        command: ["hypridle"]
        onExited: {
            caffeineCheck.running = true;
        }
    }
    
    Process {
        id: hypridleKill
        command: ["pkill", "-x", "hypridle"]
        onExited: {
            caffeineCheck.running = true;
        }
    }
    
    // Polling timer
    Timer {
        interval: 2000
        running: root.visible // only poll when visible
        repeat: true
        onTriggered: {
            pamixerGetVolume.running = true;
            pamixerGetMute.running = true;
            brightnessGet.running = true;
            wlsunsetCheck.running = true;
            caffeineCheck.running = true;
        }
    }
    
    // Helper components
    component CustomSlider: Slider {
        id: control
        
        background: Rectangle {
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 8
            width: control.availableWidth
            height: implicitHeight
            radius: 4
            color: "#313244" // surface0
            
            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                color: "#cba6f7" // mauve
                radius: 4
            }
        }
        
        handle: Rectangle {
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            color: control.pressed ? "#f38ba8" : "#cba6f7" // red / mauve
            border.color: "#1e1e2e" // base
            border.width: 2
        }
    }
    
    component ToggleButton: Rectangle {
        id: btn
        property string iconText: ""
        property string labelText: ""
        property bool active: false
        signal clicked()
        
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 8
        
        color: active ? "#cba6f7" : "#313244" // mauve / surface0
        border.color: active ? "#b4befe" : "transparent" // sapphire
        border.width: 1
        
        Behavior on color { ColorAnimation { duration: 150 } }
        
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            
            Text {
                text: btn.iconText
                color: btn.active ? "#11111b" : "#cdd6f4" // crust / text
                font.pixelSize: 18
            }
            Text {
                text: btn.labelText
                color: btn.active ? "#11111b" : "#cdd6f4" // crust / text
                font.pixelSize: 14
                font.bold: true
            }
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 16
        
        // Volume
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: isMuted ? "#f38ba8" : "#313244" // red / surface0
                
                Text {
                    anchors.centerIn: parent
                    text: isMuted ? "󰝟" : (currentVolume > 50 ? "󰕾" : "󰖀")
                    color: isMuted ? "#11111b" : "#cdd6f4"
                    font.pixelSize: 18
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pamixerToggleMute.running = true;
                    }
                }
            }
            
            CustomSlider {
                id: volSlider
                Layout.fillWidth: true
                from: 0
                to: Math.max(100, currentVolume) // Allow keeping > 100 if already there
                value: 0
                
                onMoved: {
                    pamixerSetVolume.targetVol = Math.round(value);
                    pamixerSetVolume.running = true;
                    currentVolume = Math.round(value);
                }
            }
            
            Text {
                text: currentVolume + "%"
                color: "#a6adc8"
                font.pixelSize: 12
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
        
        // Brightness
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: "#313244" // surface0
                
                Text {
                    anchors.centerIn: parent
                    text: "󰃠"
                    color: "#cdd6f4"
                    font.pixelSize: 18
                }
            }
            
            CustomSlider {
                id: brightSlider
                Layout.fillWidth: true
                from: 1 // Don't go completely dark
                to: 100
                value: 100
                
                onMoved: {
                    brightnessSet.targetPercent = Math.round(value);
                    brightnessSet.running = true;
                    currentBrightness = Math.round(value);
                }
            }
            
            Text {
                text: currentBrightness + "%"
                color: "#a6adc8"
                font.pixelSize: 12
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
        
        // Settings Toggles Grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 12
            columnSpacing: 12
            
            ToggleButton {
                iconText: "󰖔"
                labelText: "Night Mode"
                active: nightModeActive
                onClicked: {
                    if (nightModeActive) {
                        wlsunsetKill.running = true;
                    } else {
                        wlsunsetStart.running = true;
                    }
                    nightModeActive = !nightModeActive;
                }
            }
            
            ToggleButton {
                iconText: "󰅶"
                labelText: "Caffeine"
                active: caffeineActive
                onClicked: {
                    if (caffeineActive) {
                        hypridleStart.running = true;
                    } else {
                        hypridleKill.running = true;
                    }
                    caffeineActive = !caffeineActive;
                }
            }
        }
    }
}
