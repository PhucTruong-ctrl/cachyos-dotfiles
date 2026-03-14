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
            metadata: metadata || {}
        })
    }

    function publishBrightness(value, icon, metadata): void {
        root.publish("brightness", value, icon || "󰃠", "Brightness", metadata || {})
    }

    function publishVolume(value, icon, metadata): void {
        root.publish("volume", value, icon || "󰕾", "Volume", metadata || {})
    }
}
