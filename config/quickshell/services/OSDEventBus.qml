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

    function publishMedia(icon, title, source, progress): void {
        root.publish("media", progress, icon, title, {
            source: source,
            progress: progress
        })
    }
}
