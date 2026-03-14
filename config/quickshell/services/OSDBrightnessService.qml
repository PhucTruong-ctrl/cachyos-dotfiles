pragma Singleton
import QtQuick
import "./" as Services

// Singleton service module: import into shell modules, do not instantiate in shell.qml.
QtObject {
    id: root

    function publishBrightness(percent: int, icon: string, label: string, metadata: var): var {
        return Services.OSDEventBus.publishBrightness(percent, icon, label, metadata);
    }
}
