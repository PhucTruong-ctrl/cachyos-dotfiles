// ClipboardService.qml — Clipboard history backend using cliphist.
//
// Usage: import "../services" in any component, then use ClipboardService.*
//
// Exposes:
//   - clipboardItems  : ListModel   — id + text rows from `cliphist list`
//   - itemCount       : int         — convenience count
//   - refresh()       : function    — re-runs `cliphist list`, repopulates model
//   - paste(id)       : function    — decodes and re-copies the entry with given id
//   - clear()         : function    — wipes the cliphist database
//
// Must NOT use onStdout — always use stdout: SplitParser { onRead: ... }
// Must NOT store clipboard data persistently in QML — cliphist owns persistence.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Exposed properties ────────────────────────────────────────────────────
    /// ListModel with {id: string, text: string} entries from cliphist
    readonly property ListModel clipboardItems: _clipboardItems
    /// Number of items currently in the model
    readonly property int itemCount: _clipboardItems.count

    // ── Internal model ────────────────────────────────────────────────────────
    property ListModel _clipboardItems: ListModel {}

    // ── cliphist list — populates model on each refresh() call ───────────────
    property Process _listProc: Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                // cliphist list format: "<id>\t<content>"
                const tabIdx = line.indexOf("\t");
                if (tabIdx === -1) return;

                const entryId   = line.substring(0, tabIdx);
                const entryText = line.substring(tabIdx + 1);
                if (entryId === "" ) return;

                root._clipboardItems.append({ "id": entryId, "text": entryText });
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("ClipboardService: cliphist list exited with code " + exitCode);
            }
        }
    }

    // ── cliphist decode | wl-copy — re-copies a history entry ────────────────
    property Process _pasteProc: Process {
        id: pasteProc
        // command is set dynamically in paste()
        command: ["bash", "-c", "true"]
        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("ClipboardService: paste failed with exit code " + exitCode);
            }
        }
    }

    // ── cliphist wipe — clears the entire history database ───────────────────
    property Process _clearProc: Process {
        id: clearProc
        command: ["cliphist", "wipe"]
        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._clipboardItems.clear();
            } else {
                console.warn("ClipboardService: cliphist wipe failed with exit code " + exitCode);
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /// Refreshes clipboard items by running `cliphist list`.
    /// Clears the model first, then repopulates line by line.
    function refresh() {
        root._clipboardItems.clear();
        listProc.running = false;
        listProc.running = true;
    }

    /// Decodes and re-copies the entry identified by `id`.
    /// Uses: bash -c 'cliphist decode <id> | wl-copy'
    function paste(id) {
        // Escape the id safely — cliphist ids are numeric so no shell injection risk,
        // but we quote it defensively.
        const escapedId = String(id).replace(/'/g, "'\\''");
        pasteProc.command = [
            "bash", "-c",
            "cliphist decode '" + escapedId + "' | wl-copy"
        ];
        pasteProc.running = false;
        pasteProc.running = true;
    }

    /// Wipes the entire cliphist database and clears the model.
    function clear() {
        clearProc.running = false;
        clearProc.running = true;
    }
}
