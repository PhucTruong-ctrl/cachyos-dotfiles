// BluetoothService.qml — Wraps bluetoothctl commands for device state and toggle actions.
// Used by ControlCenter and status indicators.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BluetoothService — singleton service exposing the system Bluetooth state.
//
// Consumers:
//   - BluetoothToggle, BluetoothPanel (future) — read adapterAvailable, enabled, devices
//   - Control-center widgets — read connectedCount
//
// Must NOT import any UI components or create windows.
//
// Access: BluetoothService.adapterAvailable, BluetoothService.enabled, …

QtObject {
    id: root

    // ── Adapter presence ────────────────────────────────────────────────────
    // True if at least one Bluetooth adapter is available on the system.
    readonly property bool adapterAvailable: Bluetooth.defaultAdapter !== null

    // ── Power state ─────────────────────────────────────────────────────────
    // Reflects the first adapter's power state. False when no adapter exists.
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false

    // ── Device list passthrough ─────────────────────────────────────────────
    // UntypedObjectModel of BluetoothDevice exposed by the Quickshell layer.
    // UI delegates should cast items to BluetoothDevice.
    readonly property var devices: Bluetooth.devices

    // ── Connected device count ───────────────────────────────────────────────
    // Recalculates whenever the device list size changes.
    // Note: changes to individual device.connected state will NOT trigger
    // a recompute unless the model count also changes; use onDevicesChanged
    // signal on the device in UI layers for per-item tracking.
    readonly property int connectedCount: {
        const devs = Bluetooth.devices;
        if (!devs) return 0;
        let count = 0;
        for (let i = 0; i < devs.count; i++) {
            const dev = devs.get(i);
            if (dev && dev.connected) count++;
        }
        return count;
    }

    // ── Power toggle ────────────────────────────────────────────────────────
    // Flip the default adapter's power state.
    function togglePower() {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter) {
            console.warn("BluetoothService: togglePower() called but no adapter available");
            return;
        }
        adapter.enabled = !adapter.enabled;
    }

    // ── Discovery control ───────────────────────────────────────────────────
    // Begin scanning for nearby Bluetooth devices.
    function startDiscovery() {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter) {
            console.warn("BluetoothService: startDiscovery() called but no adapter available");
            return;
        }
        adapter.discovering = true;
    }

    // Stop scanning for nearby Bluetooth devices.
    function stopDiscovery() {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter) {
            console.warn("BluetoothService: stopDiscovery() called but no adapter available");
            return;
        }
        adapter.discovering = false;
    }

    // ── Startup diagnostic ──────────────────────────────────────────────────
    Component.onCompleted: {
        const adapter = Bluetooth.defaultAdapter;
        const adapterName = adapter ? adapter.name : "none";
        const powered = adapter ? adapter.enabled : false;
        console.log("BluetoothService: adapter=" + adapterName + ", powered=" + powered);
    }
}
