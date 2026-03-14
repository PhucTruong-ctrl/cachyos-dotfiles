pragma Singleton
import QtQuick

QtObject {
    id: root

    signal eventPublished(var event)

    function publish(kind, value, icon, label, metadata): void {
        root.eventPublished({
            kind: kind,
            value: value,
            icon: icon,
            label: label,
            timestamp: Date.now(),
            metadata: metadata || ({})
        })
    }

    function publishAudio(value, icon, label, metadata): void {
        root.publish("volume", value, icon, label, metadata)
    }

    function publishBrightness(value, icon, metadata): void {
        root.publish("brightness", value, icon, "", metadata)
    }

    function publishMedia(icon, title, source, progress): void {
        root.publish("media", progress, icon, title, {
            source: source,
            progress: progress
        })
    }
}
