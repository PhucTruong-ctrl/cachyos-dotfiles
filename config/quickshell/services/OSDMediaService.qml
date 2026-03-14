pragma Singleton
import QtQuick
import QtQml
import "."

QtObject {
    id: root

    property string lastSignature: ""
    property int lastEmitMs: 0
    property int minimumEmitIntervalMs: 300

    function normalizedIconFor(status): string {
        if (status === "Playing")
            return "󰐊";
        if (status === "Paused")
            return "󰏤";
        return "󰓃";
    }

    function normalizedProgressFor(status): int {
        if (status === "Playing")
            return 100;
        if (status === "Paused")
            return 50;
        return 0;
    }

    function emitMediaEvent(): void {
        const title = (MediaService.title || "").trim()
        const source = (MediaService.playerName || "").trim()
        const status = (MediaService.playbackStatus || "Stopped").trim()

        if (!title || status === "Stopped") {
            root.lastSignature = ""
            return;
        }

        const icon = root.normalizedIconFor(status)
        const progress = root.normalizedProgressFor(status)
        const signature = [title, source, status, progress].join("|")
        const now = Date.now()
        if (signature === root.lastSignature && (now - root.lastEmitMs) < root.minimumEmitIntervalMs)
            return;

        root.lastSignature = signature
        root.lastEmitMs = now
        OSDEventBus.publishMedia(icon, title, source, progress)
    }

    property Connections mediaServiceConnections: Connections {
        target: MediaService

        function onMediaStateChanged() {
            root.emitMediaEvent()
        }
    }

    Component.onCompleted: root.emitMediaEvent()
}
