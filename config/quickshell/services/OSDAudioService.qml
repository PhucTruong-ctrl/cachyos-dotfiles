pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "./" as Services

// Singleton service module: import into shell modules, do not instantiate in shell.qml.
QtObject {
    id: root

    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool audioReady: !!(audioSink && audioSink.audio)

    function publishVolume(percent: int, icon: string, label: string, metadata: var): var {
        if (!audioReady)
            return null;
        return Services.OSDEventBus.publishAudio(percent, icon, label, metadata);
    }

    function publishMute(isMuted: bool, icon: string, label: string, metadata: var): var {
        if (!audioReady)
            return null;
        return Services.OSDEventBus.publishAudio(isMuted ? 0 : 1, icon, label, metadata);
    }
}
