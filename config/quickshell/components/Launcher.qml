// Launcher.qml
// Toggleable application launcher overlay for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-launcher toggle
// Keybind example (hyprland.conf):
//   bind = SUPER, Space, exec, qs ipc call toggle-launcher toggle
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer with a dim backdrop.
//   - Clicking outside the launcher box dismisses it.
//   - Pressing Escape dismisses it.
//   - DesktopEntries provides live .desktop file enumeration (no subprocess).
//   - ScriptModel filters by name / genericName / comment as the user types.
//   - Arrow keys + Enter/Return navigate and launch.
//   - Tab bar at the top switches between "Apps" and "Clipboard" modes.
//   - In Clipboard mode, ClipboardService provides cliphist-backed history.
//   - MUST NOT take focus when not explicitly toggled (visible: false at start).

import Quickshell
import "../services"
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-launcher"
    // Invoke: qs ipc call toggle-launcher toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-launcher"

        function toggle(): void {
            console.log("[Launcher] IPC toggle called — visible was: " + launcherWindow.visible);
            if (launcherWindow.visible) {
                PopupStateService.closeAll()
            } else {
                PopupStateService.openExclusive("launcher")
            }
        }
    }

    // Close launcher when another popup opens (single-open coordination)
    Connections {
        target: PopupStateService
        function onOpenPopupIdChanged() {
            if (PopupStateService.openPopupId !== "launcher") {
                if (launcherWindow.visible) {
                    launcherWindow.visible = false
                    console.log("[Launcher] closed by PopupStateService — another popup opened")
                }
            } else {
                // "launcher" became active — open it
                if (!launcherWindow.visible) {
                    launcherWindow.visible = true
                    console.log("[Launcher] opening — resetting search and focusing input")
                    searchInput.text = ""
                    root.selectedIndex = 0
                    if (root.clipboardMode) {
                        ClipboardService.refresh()
                    }
                    searchInput.forceActiveFocus()
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────────────────────────────────
    property int  selectedIndex: 0
    property bool usingKeyboard: false   // true while navigating via arrow keys
    property bool clipboardMode: false   // true when Clipboard tab is active

    // ──────────────────────────────────────────────────────────────────────────
    // Filtered application list
    // ScriptModel re-evaluates reactively whenever `values` dependencies change.
    // ──────────────────────────────────────────────────────────────────────────
    ScriptModel {
        id: filteredApps
        // `objectProp` is used as the unique key so ListView delegates can be
        // matched to their model items without relying on index alone.
        objectProp: "id"

        values: {
            const all = [...DesktopEntries.applications.values];
            const q = searchInput.text.trim().toLowerCase();

            // No query → return full sorted list
            if (q === "") {
                return all.sort((a, b) => a.name.localeCompare(b.name));
            }

            // Filter: name, genericName, or comment contains the query
            return all.filter(d =>
                (d.name    && d.name.toLowerCase().includes(q)) ||
                (d.genericName && d.genericName.toLowerCase().includes(q)) ||
                (d.comment && d.comment.toLowerCase().includes(q))
            ).sort((a, b) => {
                // Entries whose name *starts* with the query sort first
                const an = a.name.toLowerCase();
                const bn = b.name.toLowerCase();
                const aStart = an.startsWith(q);
                const bStart = bn.startsWith(q);
                if (aStart && !bStart) return -1;
                if (!aStart && bStart) return 1;
                return an.localeCompare(bn);
            });
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Filtered clipboard list
    // A ScriptModel that filters ClipboardService.clipboardItems by search text.
    // ──────────────────────────────────────────────────────────────────────────
    ScriptModel {
        id: filteredClipboard
        objectProp: "id"

        values: {
            const q = searchInput.text.trim().toLowerCase();
            const count = ClipboardService.clipboardItems.count;
            const items = [];
            for (let i = 0; i < count; i++) {
                const item = ClipboardService.clipboardItems.get(i);
                if (q === "" || item.text.toLowerCase().includes(q)) {
                    items.push({ id: item.id, text: item.text });
                }
            }
            return items;
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: launch an app and close the launcher
    // ──────────────────────────────────────────────────────────────────────────
    function launchApp(entry) {
        console.log("[Launcher] launching app: name=" + (entry.name ?? "(unknown)") +
            " exec=" + (entry.exec ?? "(unknown)"));
        entry.execute();
        PopupStateService.closeAll();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: paste a clipboard entry and close the launcher
    // ──────────────────────────────────────────────────────────────────────────
    function pasteClipboardItem(item) {
        console.log("[Launcher] pasting clipboard item id=" + item.id);
        ClipboardService.paste(item.id);
        PopupStateService.closeAll();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // PanelWindow + Overlay layer gives us a layer-shell surface that sits above
    // all normal windows without becoming a floating top-level (which would show
    // up in the taskbar / alt-tab).
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: launcherWindow

        // ── Hidden on startup — only IPC toggle makes it visible ──────────────
        visible: false

        // Allow the launcher to receive keyboard input when shown
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-launcher"

        // Span the full screen so the dim backdrop covers everything
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Transparent – the visual background is painted inside
        color: "transparent"

        // Do not push other windows aside
        exclusionMode: ExclusionMode.Ignore

        // ── Dim backdrop (click outside → close) ──────────────────────────────
        MouseArea {
            anchors.fill: parent
            // Only close when clicking the backdrop, not the launcher box itself
            onClicked: {
                console.log("[Launcher] backdrop clicked — closing launcher");
                PopupStateService.closeAll();
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0,0,0, 0.65)   // semi-transparent black overlay
            }
        }

        // ── Centered launcher card ─────────────────────────────────────────────
        Rectangle {
            id: launcherBox
            anchors.centerIn: parent
            width:  580
            height: 500
            radius: 14

            // Catppuccin Mocha palette (matches Bar.qml)
            color:        Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
            border.color: GlobalState.surface0   // surface0
            border.width: 1

            // Prevent backdrop click from propagating through the card
            MouseArea {
                anchors.fill: parent
                onClicked: { /* swallow — do nothing */ }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                // ── Mode tab bar: "Apps" | "Clipboard" ───────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: [
                            { label: " Apps",       isClipboard: false },
                            { label: " Clipboard",  isClipboard: true  }
                        ]

                        Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            height: 32
                            radius: 8
                            // Only round corners on the relevant side
                            // We use a simpler approach: full radius, overlap via spacing=0
                            color: (root.clipboardMode === modelData.isClipboard)
                                   ? GlobalState.surface1
                                   : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Appearance.popupFade }
                            }

                            Text {
                                anchors.centerIn: parent
                                text:  modelData.label
                                color: (root.clipboardMode === modelData.isClipboard)
                                       ? GlobalState.matugenPrimary
                                       : GlobalState.overlay1
                                font.pixelSize: 13
                                font.bold: root.clipboardMode === modelData.isClipboard

                                Behavior on color {
                                    ColorAnimation { duration: Appearance.popupFade }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    const wasClipboard = root.clipboardMode;
                                    root.clipboardMode = modelData.isClipboard;
                                    root.selectedIndex = 0;
                                    searchInput.text = "";
                                    // Refresh clipboard history when switching to clipboard mode
                                    if (!wasClipboard && root.clipboardMode) {
                                        ClipboardService.refresh();
                                    }
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // ── Search box ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: GlobalState.surface0      // surface0
                    border.color: searchInput.activeFocus ? GlobalState.matugenPrimary : GlobalState.surface1
                    border.width: 1

                    // Animate border color on focus
                    Behavior on border.color {
                        ColorAnimation { duration: Appearance.popupFade }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin:  14
                        anchors.rightMargin: 14
                        spacing: 10

                        // Search icon
                        Text {
                            text: ""          // Nerd Font search glyph
                            color: GlobalState.overlay1
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Input field
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color:            GlobalState.text   // text
                            font.pixelSize:   15
                            clip:             true

                            // Placeholder text changes by mode
                            Text {
                                anchors.fill:       parent
                                text:               root.clipboardMode
                                                    ? "Search clipboard history…"
                                                    : "Type to search applications…"
                                color:              GlobalState.overlay1   // overlay0
                                font:               parent.font
                                visible:            !parent.text && !parent.activeFocus
                                verticalAlignment:  Text.AlignVCenter
                            }

                            // Reset selection on every keystroke
                            onTextChanged: root.selectedIndex = 0

                            // ── Keyboard navigation ───────────────────────────
                            Keys.onEscapePressed: {
                                console.log("[Launcher] Escape pressed — closing launcher");
                                PopupStateService.closeAll();
                            }

                            Keys.onDownPressed: {
                                root.usingKeyboard = true;
                                root.selectedIndex = Math.min(
                                    root.selectedIndex + 1,
                                    resultsList.count - 1
                                );
                                console.log("[Launcher] key Down — selectedIndex=" + root.selectedIndex);
                                resultsList.positionViewAtIndex(
                                    root.selectedIndex, ListView.Contain
                                );
                            }

                            Keys.onUpPressed: {
                                root.usingKeyboard = true;
                                root.selectedIndex = Math.max(
                                    root.selectedIndex - 1, 0
                                );
                                console.log("[Launcher] key Up — selectedIndex=" + root.selectedIndex);
                                resultsList.positionViewAtIndex(
                                    root.selectedIndex, ListView.Contain
                                );
                            }

                            Keys.onTabPressed: {
                                root.usingKeyboard = true;
                                root.selectedIndex = Math.min(
                                    root.selectedIndex + 1,
                                    resultsList.count - 1
                                );
                                resultsList.positionViewAtIndex(
                                    root.selectedIndex, ListView.Contain
                                );
                            }

                            Keys.onReturnPressed: {
                                if (resultsList.count > 0) {
                                    if (root.clipboardMode) {
                                        const item = filteredClipboard.values[root.selectedIndex];
                                        if (item) root.pasteClipboardItem(item);
                                    } else {
                                        const entry = filteredApps.values[root.selectedIndex];
                                        if (entry) root.launchApp(entry);
                                    }
                                }
                            }

                            Keys.onEnterPressed: {
                                if (resultsList.count > 0) {
                                    if (root.clipboardMode) {
                                        const item = filteredClipboard.values[root.selectedIndex];
                                        if (item) root.pasteClipboardItem(item);
                                    } else {
                                        const entry = filteredApps.values[root.selectedIndex];
                                        if (entry) root.launchApp(entry);
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Result count hint + Clear All (clipboard mode only) ───────
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: resultsList.count + " result" +
                              (resultsList.count !== 1 ? "s" : "")
                        color:          GlobalState.overlay1
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    // Clear All button — only shown in clipboard mode
                    Rectangle {
                        visible: root.clipboardMode
                        width:   clearAllLabel.implicitWidth + 20
                        height:  22
                        radius:  6
                        color:   clearAllArea.containsMouse
                                 ? GlobalState.surface1
                                 : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Appearance.popupFade }
                        }

                        Text {
                            id: clearAllLabel
                            anchors.centerIn: parent
                            text:             " Clear All"
                            color:            GlobalState.red ?? "#F38BA8"
                            font.pixelSize:   11
                        }

                        MouseArea {
                            id: clearAllArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                console.log("[Launcher] Clear All clipboard history");
                                ClipboardService.clear();
                            }
                        }
                    }
                }

                // ── Results list ──────────────────────────────────────────────
                ListView {
                    id: resultsList
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    // Switch model between apps and clipboard depending on mode
                    model:             root.clipboardMode ? filteredClipboard : filteredApps
                    clip:              true
                    spacing:           2
                    boundsBehavior:    Flickable.StopAtBounds
                    currentIndex:      root.selectedIndex
                    highlightMoveDuration: 120
                    highlightMoveVelocity: -1

                    // Selection highlight bar
                    highlight: Rectangle {
                        radius: 8
                        color:  GlobalState.surface0   // surface0

                        // Left accent stripe
                        Rectangle {
                            width:  3
                            height: 22
                            radius: 2
                            color:  GlobalState.matugenPrimary   // mauve
                            anchors.left:            parent.left
                            anchors.leftMargin:      3
                            anchors.verticalCenter:  parent.verticalCenter
                        }
                    }

                    // ── App delegate (shown in Apps mode) ────────────────────
                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index

                        width:  resultsList.width
                        height: 46
                        radius: 8
                        color:  hoverArea.containsMouse &&
                                root.selectedIndex !== index
                                ? GlobalState.mantle   // mantle — subtle hover tint
                                : "transparent"
                        visible: true

                        Behavior on color {
                            ColorAnimation { duration: Appearance.popupFade }
                        }

                        // ── App mode row ──────────────────────────────────────
                        RowLayout {
                            anchors.fill:        parent
                            anchors.leftMargin:  12
                            anchors.rightMargin: 12
                            spacing: 12
                            visible: !root.clipboardMode

                            // ── App icon ──────────────────────────────────────
                            Item {
                                width:  28
                                height: 28
                                Layout.alignment: Qt.AlignVCenter

                                IconImage {
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(
                                        (delegateRoot.modelData.icon ?? ""), true
                                    )
                                    visible: (delegateRoot.modelData.icon ?? "") !== ""
                                }

                                // Fallback glyph when no icon is available
                                Text {
                                    anchors.centerIn: parent
                                    text:             ""   // Nerd Font terminal glyph
                                    color:            GlobalState.matugenPrimary
                                    font.pixelSize:   20
                                    visible: (delegateRoot.modelData.icon ?? "") === ""
                                }
                            }

                            // ── Text info ─────────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth:  true
                                Layout.alignment:  Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text:  delegateRoot.modelData.name ?? ""
                                    color: root.selectedIndex === delegateRoot.index
                                           ? GlobalState.text
                                           : GlobalState.subtext0
                                    font.pixelSize: 13
                                    font.bold: root.selectedIndex === delegateRoot.index
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: delegateRoot.modelData.genericName ??
                                          delegateRoot.modelData.comment ?? ""
                                    color:          GlobalState.overlay1
                                    font.pixelSize: 11
                                    elide:          Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        // ── Clipboard mode row ────────────────────────────────
                        RowLayout {
                            anchors.fill:        parent
                            anchors.leftMargin:  12
                            anchors.rightMargin: 12
                            spacing: 12
                            visible: root.clipboardMode

                            // Clipboard icon
                            Text {
                                text:             ""   // Nerd Font clipboard glyph
                                color:            root.selectedIndex === delegateRoot.index
                                                  ? GlobalState.matugenPrimary
                                                  : GlobalState.overlay1
                                font.pixelSize:   18
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Clipboard text content (truncated)
                            Text {
                                text:  delegateRoot.modelData.text ?? ""
                                color: root.selectedIndex === delegateRoot.index
                                       ? GlobalState.text
                                       : GlobalState.subtext0
                                font.pixelSize:  13
                                font.bold:       root.selectedIndex === delegateRoot.index
                                elide:           Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill:  parent
                            hoverEnabled:  true
                            cursorShape:   Qt.PointingHandCursor
                            onClicked: {
                                if (root.clipboardMode) {
                                    console.log("[Launcher] clipboard item clicked: id=" +
                                        (delegateRoot.modelData.id ?? "(unknown)"));
                                    root.pasteClipboardItem(delegateRoot.modelData);
                                } else {
                                    console.log("[Launcher] app item clicked: name=" +
                                        (delegateRoot.modelData.name ?? "(unknown)"));
                                    root.launchApp(delegateRoot.modelData);
                                }
                            }
                            onPositionChanged: {
                                // Mouse moved — switch back to mouse-driven selection
                                root.usingKeyboard = false;
                                root.selectedIndex = delegateRoot.index;
                            }
                        }
                    }

                    // ── Empty state ───────────────────────────────────────────
                    Text {
                        anchors.centerIn: parent
                        text: root.clipboardMode
                              ? "No clipboard history"
                              : "No applications found"
                        color: GlobalState.overlay1
                        font.pixelSize: 14
                        visible: resultsList.count === 0
                    }
                }

                // ── Keyboard shortcut hints ───────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: root.clipboardMode
                            ? [
                                { key: "↑↓",    label: "navigate" },
                                { key: "⏎",     label: "paste"    },
                                { key: "Esc",   label: "close"    }
                              ]
                            : [
                                { key: "↑↓",    label: "navigate" },
                                { key: "⏎",     label: "launch"   },
                                { key: "Esc",   label: "close"    }
                              ]

                        Row {
                            required property var modelData
                            spacing: 4

                            Rectangle {
                                width:  keyLabel.implicitWidth + 8
                                height: 18
                                radius: 4
                                color:  GlobalState.surface0

                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text:             modelData.key
                                    color:            GlobalState.overlay1
                                    font.pixelSize:   10
                                }
                            }

                            Text {
                                text:           modelData.label
                                color:          GlobalState.overlay1
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
