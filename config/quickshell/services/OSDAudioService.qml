pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import "."
QtObject {
    id: root

    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool audioReady: !!(root.audioSink && root.audioSink.audio)

    property int _lastVolume: -1
    property bool _lastMuted: false
    property bool _hasState: false

    function sinkVolumePercent() {
        if (!root.audioReady)
            return root._lastVolume >= 0 ? root._lastVolume : 0;
        const vol = Math.round(root.audioSink.audio.volume * 100)
        return isNaN(vol) ? (root._lastVolume >= 0 ? root._lastVolume : 0) : vol
    }

    function syncSinkState() {
        if (!root.audioReady) {
            root._hasState = false
            return
        }
        root._lastVolume = root.sinkVolumePercent()
        root._lastMuted = root.audioSink.audio.muted
        root._hasState = true
    }

    function publishCurrentState(reason) {
        if (!root.audioReady)
            return;

        const vol = root.sinkVolumePercent()
        const isMuted = root.audioSink.audio.muted
        if (!root._hasState) {
            root._lastVolume = vol
            root._lastMuted = isMuted
            root._hasState = true
            return
        }

        let volumeChanged = false
        if (!isNaN(vol) && vol !== root._lastVolume)
            volumeChanged = true
        let muteChanged = false
        if (isMuted !== root._lastMuted)
            muteChanged = true
        if (!volumeChanged && !muteChanged)
            return;

        root._lastVolume = vol
        root._lastMuted = isMuted
        OSDEventBus.publishAudio(vol, isMuted ? "󰖁" : "󰕾", "volume", {
            muted: isMuted,
            reason: reason
        })
    }

    property Connections _audioConnections: Connections {
        target: root.audioSink?.audio ?? null

        function onVolumeChanged() {
            root.publishCurrentState("volume")
        }

        function onMutedChanged() {
            root.publishCurrentState("mute")
        }
    }

    property Connections _pipewireConnections: Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            root.syncSinkState()
        }
    }

    Component.onCompleted: root.syncSinkState()
}
