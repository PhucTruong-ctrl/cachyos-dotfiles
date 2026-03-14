pragma Singleton
import QtQuick
import "./" as Services

// Singleton service module: import into shell modules, do not instantiate in shell.qml.
QtObject {
    id: root

    function publishMedia(state: string, icon: string, label: string, metadata: var): var {
        return Services.OSDEventBus.publishMedia(state, icon, label, metadata);
    }
}
