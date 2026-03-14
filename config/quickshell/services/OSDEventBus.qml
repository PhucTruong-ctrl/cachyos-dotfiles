pragma Singleton
import QtQuick

QtObject {
    id: root

    property var lastEvent: ({
            kind: "",
            value: 0,
            icon: "",
            label: "",
            timestamp: 0,
            metadata: ({})
        })

    signal showRequested(string kind, int value, string icon, string label, var metadata, double timestamp)

    function publish(kind, value, icon, label, metadata = ({})) {
        const eventTimestamp = Date.now()
        root.lastEvent = {
            kind: kind,
            value: value,
            icon: icon,
            label: label,
            timestamp: eventTimestamp,
            metadata: metadata
        }
        root.showRequested(kind, value, icon, label, metadata, eventTimestamp)
    }

    function publishAudio(value, icon, label, metadata = ({})) {
        root.publish("volume", value, icon, label, metadata)
    }
}
