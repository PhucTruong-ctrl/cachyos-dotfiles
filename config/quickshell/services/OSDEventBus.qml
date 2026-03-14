pragma Singleton
import QtQuick

// Singleton service module: import into shell modules, do not instantiate in shell.qml.
QtObject {
    id: root

    readonly property list<string> supportedKinds: ["audio", "brightness", "media"]
    readonly property var emptyMetadata: ({})

    signal eventPublished(var payload)

    property var lastEvent: ({
        "kind": "",
        "value": 0,
        "icon": "",
        "label": "",
        "timestamp": 0,
        "metadata": ({})
    })

    function normalizeEvent(kind: string, value: var, icon: string, label: string, metadata: var): var {
        const eventTimestamp = Date.now();
        return {
            "kind": kind,
            "value": value,
            "icon": icon,
            "label": label,
            "timestamp": eventTimestamp,
            "metadata": metadata && typeof metadata === "object" ? metadata : ({})
        };
    }

    function publish(kind: string, value: var, icon: string, label: string, metadata: var): var {
        const payload = normalizeEvent(kind, value, icon, label, metadata);
        lastEvent = payload;
        eventPublished(payload);
        return payload;
    }

    function publishAudio(value: var, icon: string, label: string, metadata: var): var {
        return publish("audio", value, icon, label, metadata);
    }

    function publishBrightness(value: var, icon: string, label: string, metadata: var): var {
        return publish("brightness", value, icon, label, metadata);
    }

    function publishMedia(value: var, icon: string, label: string, metadata: var): var {
        return publish("media", value, icon, label, metadata);
    }
}
