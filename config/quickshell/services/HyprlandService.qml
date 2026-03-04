// HyprlandService.qml — Utility layer for `hyprctl clients/workspaces/dispatch` commands.
// Overview and workspace widgets consume its JSON data + helpers.

pragma Singleton
// HyprlandService.qml — Hyprland IPC client singleton
//
// Provides:
//   fetchClients()     — queries `hyprctl clients -j`, populates clientModel
//   fetchWorkspaces()  — queries `hyprctl workspaces -j`, populates workspaceModel
//   focusWindow(addr)  — dispatches focuswindow address:<addr>
//   moveToWorkspace(id)— dispatches workspace <id>
//
// Signals:
//   windowMoved()      — emitted when moveWindowToWorkspace dispatch completes
//
// Models use ListModel for reactive consumption by Overview.qml.
// Processes use stdout: SplitParser { onRead: ... } — never onStdout.

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Public models ─────────────────────────────────────────────────────────
    /// Populated by fetchClients().
    /// Each element: { address, klass, title, workspaceId, workspaceName,
    ///                 atX, atY, sizeW, sizeH, mapped, icon }
    property ListModel clientModel: ListModel {}

    /// Populated by fetchWorkspaces().
    /// Each element: { id, name, windows }
    property ListModel workspaceModel: ListModel {}

    // ── Signals ───────────────────────────────────────────────────────────────
    /// Emitted after moveWindowToWorkspace dispatch exits successfully.
    /// Consumers (e.g. Overview) should use this to refresh state rather than
    /// relying on a fixed-duration timer.
    signal windowMoved()

    // ── Internal JSON accumulator ─────────────────────────────────────────────
    property string _clientsBuf:    ""
    property string _workspacesBuf: ""

    // ── hyprctl clients -j ────────────────────────────────────────────────────
    property Process _clientsProc: Process {
        id: clientsProc
        running: false

        stdout: SplitParser {
            splitMarker: ""   // accumulate full output (no line splitting)
            onRead: data => {
                root._clientsBuf += data;
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("[HyprlandService] hyprctl clients -j failed (exit " + exitCode + ")");
                root._clientsBuf = "";
                return;
            }
            const raw = root._clientsBuf.trim();
            root._clientsBuf = "";
            if (raw.length === 0) return;
            try {
                const clients = JSON.parse(raw);
                root.clientModel.clear();
                for (let i = 0; i < clients.length; i++) {
                    const c = clients[i];
                    if (!c.mapped) continue;   // skip unmapped windows
                    root.clientModel.append({
                        "address":       c.address       || "",
                        "klass":         c["class"]      || "",
                        "title":         c.title         || "",
                        "workspaceId":   (c.workspace && c.workspace.id)   ? c.workspace.id   : 0,
                        "workspaceName": (c.workspace && c.workspace.name) ? c.workspace.name : "",
                        "atX":           (c.at && c.at[0] !== undefined)   ? c.at[0]          : 0,
                        "atY":           (c.at && c.at[1] !== undefined)   ? c.at[1]          : 0,
                        "sizeW":         (c.size && c.size[0] !== undefined) ? c.size[0]       : 100,
                        "sizeH":         (c.size && c.size[1] !== undefined) ? c.size[1]       : 100,
                        "icon":          c["class"]      || ""
                    });
                }
                console.log("[HyprlandService] fetchClients: loaded " + root.clientModel.count + " clients");
            } catch(e) {
                console.error("[HyprlandService] failed to parse clients JSON: " + e);
            }
        }
    }

    // ── hyprctl workspaces -j ─────────────────────────────────────────────────
    property Process _workspacesProc: Process {
        id: workspacesProc
        running: false

        stdout: SplitParser {
            splitMarker: ""   // accumulate full output
            onRead: data => {
                root._workspacesBuf += data;
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("[HyprlandService] hyprctl workspaces -j failed (exit " + exitCode + ")");
                root._workspacesBuf = "";
                return;
            }
            const raw = root._workspacesBuf.trim();
            root._workspacesBuf = "";
            if (raw.length === 0) return;
            try {
                const workspaces = JSON.parse(raw);
                root.workspaceModel.clear();
                // Sort by workspace id for stable column order
                workspaces.sort((a, b) => a.id - b.id);
                for (let i = 0; i < workspaces.length; i++) {
                    const w = workspaces[i];
                    root.workspaceModel.append({
                        "id":      w.id      || 0,
                        "name":    w.name    || String(w.id),
                        "windows": w.windows || 0
                    });
                }
                console.log("[HyprlandService] fetchWorkspaces: loaded " + root.workspaceModel.count + " workspaces");
            } catch(e) {
                console.error("[HyprlandService] failed to parse workspaces JSON: " + e);
            }
        }
    }

    // ── hyprctl dispatch focuswindow ──────────────────────────────────────────
    property Process _focusProc: Process {
        id: focusProc
        running: false
    }

    // ── hyprctl dispatch workspace ────────────────────────────────────────────
    property Process _workspaceProc: Process {
        id: workspaceProc
        running: false
    }

    // ── hyprctl dispatch movetoworkspacesilent ────────────────────────────────
    property Process _moveWindowProc: Process {
        id: moveWindowProc
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                // Notify listeners (e.g. Overview) that the move is complete
                root.windowMoved();
            } else {
                console.warn("[HyprlandService] movetoworkspacesilent failed (exit " + exitCode + ")");
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /// Refresh clientModel from hyprctl clients -j
    function fetchClients() {
        root._clientsBuf = "";
        clientsProc.command = ["hyprctl", "clients", "-j"];
        clientsProc.running = false;
        clientsProc.running = true;
    }

    /// Refresh workspaceModel from hyprctl workspaces -j
    function fetchWorkspaces() {
        root._workspacesBuf = "";
        workspacesProc.command = ["hyprctl", "workspaces", "-j"];
        workspacesProc.running = false;
        workspacesProc.running = true;
    }

    /// Focus a window by address and close overview
    function focusWindow(address) {
        console.log("[HyprlandService] focusWindow: " + address);
        focusProc.command = ["hyprctl", "dispatch", "focuswindow", "address:" + address];
        focusProc.running = false;
        focusProc.running = true;
    }

    /// Switch to a workspace by id
    function moveToWorkspace(id) {
        console.log("[HyprlandService] moveToWorkspace: " + id);
        workspaceProc.command = ["hyprctl", "dispatch", "workspace", String(id)];
        workspaceProc.running = false;
        workspaceProc.running = true;
    }

    /// Silently move a window to a workspace (drag-and-drop use case).
    /// Dispatches: hyprctl dispatch movetoworkspacesilent <workspaceId>,address:<address>
    function moveWindowToWorkspace(address, workspaceId) {
        console.log("[HyprlandService] moveWindowToWorkspace: address=" + address + " ws=" + workspaceId);
        moveWindowProc.command = [
            "hyprctl", "dispatch", "movetoworkspacesilent",
            String(workspaceId) + ",address:" + address
        ];
        moveWindowProc.running = false;
        moveWindowProc.running = true;
    }
}
