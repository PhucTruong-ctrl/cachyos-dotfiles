// Overview.qml
// Fullscreen window-switcher overlay for Quickshell / Hyprland.
//
// IPC toggle:  qs ipc call toggle-overview toggle
// Keybind (hyprland.conf):
//   bind = SUPER, Tab, exec, qs ipc call toggle-overview toggle
//
// Design:
//   - Full-screen PanelWindow on the Overlay layer, no exclusion zone.
//   - Adaptive workspace layout:
//       * 1-6 workspaces: horizontal row of columns
//       * 7+ workspaces: compact grid (end-4-like density)
//   - Window cards: app class icon + truncated title, proportionally sized.
//   - Click a card  → focus window, close overview.
//   - Drag a card   → drag it across workspace columns; drop to move window.
//   - Click empty workspace area → switch to workspace, close overview.
//   - Search bar filters by title/class.
//   - Escape or backdrop click → close.
//   - Refreshes window and workspace list every time it opens.
//   - All colors from GlobalState; all animations from Appearance.

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
    // Drag-and-drop state (shared between window cards and workspace drop zones)
    // ──────────────────────────────────────────────────────────────────────────
    /// True while a window card is being dragged.
    property bool draggingWindow: false
    /// The workspace id currently hovered during a drag (-1 = none).
    property int  hoveredWorkspaceId: -1
    /// Address/workspace of the card currently being dragged.
    property string draggedWindowAddress: ""
    property int draggedFromWorkspaceId: -1
    /// Layout tuning for many workspaces.
    property bool useGridLayout: HyprlandService.workspaceModel.count >= 7
    property int workspaceSpacing: 14

    // End-4-like matrix controls
    property int gridRows: 2
    property int gridCols: 4
    readonly property int workspacesPerPage: gridRows * gridCols
    property int workspacePage: 0

    function maxWorkspacePage() {
        const total = HyprlandService.workspaceModel.count;
        if (total <= 0) return 0;
        return Math.max(0, Math.ceil(total / workspacesPerPage) - 1);
    }

    function workspaceInCurrentPage(wsId) {
        const start = workspacePage * workspacesPerPage + 1;
        const end = start + workspacesPerPage - 1;
        return wsId >= start && wsId <= end;
    }

    function syncWorkspacePageToActive() {
        const activeWs = Math.max(1, HyprlandService.activeWorkspaceId);
        const targetPage = Math.floor((activeWs - 1) / workspacesPerPage);
        const bounded = Math.max(0, Math.min(maxWorkspacePage(), targetPage));
        if (workspacePage !== bounded)
            workspacePage = bounded;
    }

    function pageLabel() {
        const start = workspacePage * workspacesPerPage + 1;
        const end = Math.min(HyprlandService.workspaceModel.count, start + workspacesPerPage - 1);
        return start + "–" + end;
    }

    function goPrevPage() {
        workspacePage = Math.max(0, workspacePage - 1);
    }

    function goNextPage() {
        workspacePage = Math.min(maxWorkspacePage(), workspacePage + 1);
    }

    Connections {
        target: HyprlandService
        function onActiveWorkspaceIdChanged() {
            if (root.useGridLayout)
                root.syncWorkspacePageToActive();
        }
    }

    Connections {
        target: HyprlandService.workspaceModel
        function onCountChanged() {
            if (root.workspacePage > root.maxWorkspacePage())
                root.workspacePage = root.maxWorkspacePage();
            if (root.useGridLayout)
                root.syncWorkspacePageToActive();
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Post-drop refresh — triggered by HyprlandService.windowMoved signal.
    // A short single-shot timer debounces rapid consecutive moves so we issue
    // only one fetch pair even if multiple signals fire quickly.
    // ──────────────────────────────────────────────────────────────────────────
    Timer {
        id: dragDropRefreshTimer
        interval: 50
        repeat:   false
        onTriggered: {
            HyprlandService.fetchWorkspaces();
            HyprlandService.fetchClients();
        }
    }

    Connections {
        target: HyprlandService
        function onWindowMoved() {
            dragDropRefreshTimer.restart();
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // IPC Handler — target: "toggle-overview"
    // Invoke: qs ipc call toggle-overview toggle
    // ──────────────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "toggle-overview"

        function toggle(): void {
            console.log("[Overview] IPC toggle called — visible was: " + overviewWindow.visible);
            overviewWindow.visible = !overviewWindow.visible;
            if (overviewWindow.visible) {
                console.log("[Overview] opening — refreshing window list");
                searchInput.text = "";
                root.draggingWindow   = false;
                root.hoveredWorkspaceId = -1;
                HyprlandService.fetchWorkspaces();
                HyprlandService.fetchClients();
                searchInput.forceActiveFocus();
            } else {
                console.log("[Overview] closing");
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: close overview
    // ──────────────────────────────────────────────────────────────────────────
    function close() {
        overviewWindow.visible = false;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: filter clients for a given workspaceId by current search query
    // Returns a plain JS array of client objects.
    // ──────────────────────────────────────────────────────────────────────────
    function clientsForWorkspace(wsId) {
        const q = searchInput.text.trim().toLowerCase();
        const result = [];
        const count = HyprlandService.clientModel.count;
        for (let i = 0; i < count; i++) {
            const c = HyprlandService.clientModel.get(i);
            if (c.workspaceId !== wsId) continue;
            if (q !== "" &&
                !c.title.toLowerCase().includes(q) &&
                !c.klass.toLowerCase().includes(q)) {
                continue;
            }
            result.push({
                address:       c.address,
                klass:         c.klass,
                title:         c.title,
                workspaceId:   c.workspaceId,
                workspaceName: c.workspaceName,
                sizeW:         c.sizeW,
                sizeH:         c.sizeH,
                icon:          c.icon
            });
        }
        return result;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Full-screen Overlay Window
    // ──────────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: overviewWindow

        // Hidden on startup — only IPC toggle makes it visible
        visible: false

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell-overview"

        // Span the full screen
        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // ── Root item for key handling ────────────────────────────────────────
        Item {
            id: overviewRoot
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: {
                console.log("[Overview] Escape — closing");
                root.close();
            }

            Keys.onPressed: event => {
                if (!root.useGridLayout) return;
                if (event.key === Qt.Key_Left) {
                    root.goPrevPage();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.goNextPage();
                    event.accepted = true;
                }
            }

            // ── Dim backdrop ──────────────────────────────────────────────────
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("[Overview] backdrop clicked — closing");
                    root.close();
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.75)
                }
            }

            // ── Main panel ────────────────────────────────────────────────────
            // Stop click-through from backdrop
            MouseArea {
                id: panelArea
                anchors.centerIn:  parent
                width:  Math.min(parent.width  - 80, 1400)
                height: Math.min(parent.height - 80, 800)
                onClicked: { /* swallow */ }

                Rectangle {
                    id: overviewPanel
                    anchors.fill: parent
                    radius: Appearance.panelRadius
                    color:  Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
                    border.color: GlobalState.surface0
                    border.width: 1

                    ColumnLayout {
                        anchors.fill:    parent
                        anchors.margins: 20
                        spacing: 14

                        // ── Header row: title + search bar ────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Panel title
                            Text {
                                text:           " Overview"
                                color:          GlobalState.matugenPrimary
                                font.pixelSize: 18
                                font.bold:      true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            // Search box
                            Rectangle {
                                width:  280
                                height: 36
                                radius: 8
                                color:  GlobalState.surface0
                                border.color: searchInput.activeFocus
                                              ? GlobalState.matugenPrimary
                                              : GlobalState.surface1
                                border.width: 1

                                Behavior on border.color {
                                    ColorAnimation { duration: Appearance.popupFade }
                                }

                                RowLayout {
                                    anchors.fill:          parent
                                    anchors.leftMargin:    10
                                    anchors.rightMargin:   10
                                    spacing: 8

                                    Text {
                                        text:             ""   // Nerd Font search
                                        color:            GlobalState.overlay1
                                        font.pixelSize:   14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    TextInput {
                                        id: searchInput
                                        Layout.fillWidth:  true
                                        Layout.alignment:  Qt.AlignVCenter
                                        color:             GlobalState.text
                                        font.pixelSize:    13
                                        clip:              true

                                        Text {
                                            anchors.fill:      parent
                                            text:              "Filter windows…"
                                            color:             GlobalState.overlay1
                                            font:              parent.font
                                            visible:           !parent.text && !parent.activeFocus
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Keys.onEscapePressed: root.close()
                                    }
                                }
                            }

                            // Close hint
                            Text {
                                text:             "Esc to close"
                                color:            GlobalState.overlay1
                                font.pixelSize:   11
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // ── Divider ───────────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color:  GlobalState.surface0
                        }

                        // ── Workspace columns / grid ──────────────────────────
                        // 1-6 workspaces: horizontal row
                        // 7+ workspaces: compact 2-row grid
                        ScrollView {
                            id: workspaceScroll
                            Layout.fillWidth:  true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: root.useGridLayout ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
                            ScrollBar.vertical.policy:   ScrollBar.AlwaysOff

                            // Empty state
                            Text {
                                anchors.centerIn: parent
                                text:    "No open windows"
                                color:   GlobalState.overlay1
                                font.pixelSize: 16
                                visible: HyprlandService.workspaceModel.count === 0
                            }

                            Flow {
                                id: workspaceFlow
                                spacing: root.workspaceSpacing
                                width: root.useGridLayout ? workspaceScroll.width : implicitWidth
                                height: root.useGridLayout ? implicitHeight : workspaceScroll.height
                                flow: Flow.LeftToRight

                                // Aim for 2-4 columns in grid mode depending on panel width.
                                property int columnsForGrid: Math.max(2, Math.min(4,
                                    Math.floor((workspaceScroll.width + root.workspaceSpacing) / (240 + root.workspaceSpacing))))
                                // Two visible rows gives a compact but readable overview.
                                property int gridTileHeight: Math.max(250,
                                    Math.floor((workspaceScroll.height - root.workspaceSpacing) / 2))

                                Repeater {
                                    model: HyprlandService.workspaceModel

                                    // ── Workspace column ──────────────────────
                                    Rectangle {
                                        required property var  modelData
                                        required property int  index

                                        visible: !root.useGridLayout || root.workspaceInCurrentPage(modelData.id)

                                        // workspaceClients is refreshed when search changes
                                        // or model changes.
                                        property var workspaceClients: root.clientsForWorkspace(modelData.id)

                                        // True when this column is the active drop target
                                        property bool isDragTarget: root.draggingWindow && root.hoveredWorkspaceId === modelData.id

                                        // Connections to refresh clients when model or search changes
                                        Connections {
                                            target: HyprlandService.clientModel
                                            function onCountChanged() {
                                                workspaceClients = root.clientsForWorkspace(modelData.id);
                                            }
                                        }
                                        Connections {
                                            target: searchInput
                                            function onTextChanged() {
                                                workspaceClients = root.clientsForWorkspace(modelData.id);
                                            }
                                        }

                                        width: root.useGridLayout
                                               ? Math.max(180, Math.floor((workspaceFlow.width - (root.gridCols - 1) * root.workspaceSpacing) / root.gridCols))
                                               : 220
                                        height: root.useGridLayout ? workspaceFlow.gridTileHeight : workspaceScroll.height
                                        radius: 10
                                        color: isDragTarget
                                               ? Qt.rgba(GlobalState.matugenPrimary.r, GlobalState.matugenPrimary.g, GlobalState.matugenPrimary.b, 0.15)
                                               : (wsHoverArea.containsMouse && workspaceClients.length === 0
                                                  ? Qt.rgba(GlobalState.surface0.r, GlobalState.surface0.g, GlobalState.surface0.b, 0.4)
                                                  : Qt.rgba(GlobalState.mantle.r, GlobalState.mantle.g, GlobalState.mantle.b, 0.6))
                                        border.color: isDragTarget
                                                      ? GlobalState.matugenPrimary
                                                      : GlobalState.surface1
                                        border.width: isDragTarget ? 2 : 1

                                        Behavior on color {
                                            ColorAnimation { duration: Appearance.popupFade }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: Appearance.popupFade }
                                        }

                                        ColumnLayout {
                                            anchors.fill:    parent
                                            anchors.margins: 10
                                            spacing: 8

                                            // ── Workspace header ──────────────
                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text:             " " + modelData.name
                                                    color:            GlobalState.matugenPrimary
                                                    font.pixelSize:   13
                                                    font.bold:        true
                                                    elide:            Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text:           workspaceClients.length + " win"
                                                    color:          GlobalState.overlay1
                                                    font.pixelSize: 10
                                                }
                                            }

                                            // ── Divider under header ──────────
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color:  GlobalState.surface1
                                            }

                                            // ── Window cards ─────────────────
                                            // Use a Flickable so cards can scroll vertically
                                            Flickable {
                                                id: cardsFlickable
                                                Layout.fillWidth:  true
                                                Layout.fillHeight: true
                                                contentHeight:     cardsColumn.implicitHeight
                                                clip:              true
                                                boundsBehavior:    Flickable.StopAtBounds
                                                // Important for drag-and-drop: don't let Flickable steal drags
                                                // while moving a card between workspace columns.
                                                interactive:       !root.draggingWindow

                                                Column {
                                                    id: cardsColumn
                                                    width:   parent.width
                                                    spacing: 6

                                                    Repeater {
                                                        model: workspaceClients

                                                         // ── Window card ───────
                                                        Rectangle {
                                                            id: windowCard
                                                            required property var modelData
                                                            required property int index
                                                            property bool wasDragged: false

                                                            width:  parent.width
                                                            // Proportional height: clamp to 60–100px
                                                            height: {
                                                                const ratio = (modelData.sizeH > 0 && modelData.sizeW > 0)
                                                                              ? modelData.sizeH / modelData.sizeW
                                                                              : 0.5;
                                                                return Math.max(60, Math.min(100, Math.round(200 * ratio)));
                                                            }
                                                            radius: 8

                                                            // Highlight when being dragged or hovered
                                                            color:  (cardArea.containsMouse || cardDragHandler.active)
                                                                    ? GlobalState.surface1
                                                                    : GlobalState.surface0
                                                            border.color: (cardArea.containsMouse || cardDragHandler.active)
                                                                          ? GlobalState.matugenPrimary
                                                                          : "transparent"
                                                            border.width: 1

                                                            Behavior on color {
                                                                ColorAnimation { duration: Appearance.popupFade }
                                                            }
                                                            Behavior on border.color {
                                                                ColorAnimation { duration: Appearance.popupFade }
                                                            }

                                                            // ── Drag attached properties ──
                                                            // Use MouseArea drag state (end-4-style) so DropArea
                                                            // reliably receives drag enter/exit/drop events.
                                                            Drag.active:   cardArea.drag.active
                                                            Drag.source:   windowCard
                                                            Drag.hotSpot.x: width  / 2
                                                            Drag.hotSpot.y: height / 2

                                                            RowLayout {
                                                                anchors.fill:          parent
                                                                anchors.leftMargin:    8
                                                                anchors.rightMargin:   8
                                                                anchors.topMargin:     6
                                                                anchors.bottomMargin:  6
                                                                spacing: 8

                                                                // App icon
                                                                Item {
                                                                    width:  28
                                                                    height: 28
                                                                    Layout.alignment: Qt.AlignVCenter

                                                                    IconImage {
                                                                        anchors.fill: parent
                                                                        source: Quickshell.iconPath(modelData.icon, true)
                                                                        backer.sourceSize.width: 28
                                                                        backer.sourceSize.height: 28
                                                                        visible: modelData.icon !== ""
                                                                    }

                                                                    // Fallback glyph
                                                                    Text {
                                                                        anchors.centerIn: parent
                                                                        text:             ""   // Nerd Font window glyph
                                                                        color:            GlobalState.matugenPrimary
                                                                        font.pixelSize:   20
                                                                        visible: modelData.icon === ""
                                                                    }
                                                                }

                                                                // Title + class
                                                                ColumnLayout {
                                                                    Layout.fillWidth: true
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    spacing: 2

                                                                    Text {
                                                                        text:           modelData.title
                                                                        color:          GlobalState.text
                                                                        font.pixelSize: 12
                                                                        font.bold:      cardArea.containsMouse
                                                                        elide:          Text.ElideRight
                                                                        Layout.fillWidth: true

                                                                        Behavior on color {
                                                                            ColorAnimation { duration: Appearance.popupFade }
                                                                        }
                                                                    }

                                                                    Text {
                                                                        text:           modelData.klass
                                                                        color:          GlobalState.overlay1
                                                                        font.pixelSize: 10
                                                                        elide:          Text.ElideRight
                                                                        Layout.fillWidth: true
                                                                    }
                                                                }
                                                            }

                                                            // ── Click handler ─────
                                                            MouseArea {
                                                                id: cardArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                acceptedButtons: Qt.LeftButton
                                                                preventStealing: true
                                                                drag.target: windowCard
                                                                cursorShape: cardDragHandler.active
                                                                             ? Qt.ClosedHandCursor
                                                                             : Qt.PointingHandCursor

                                                                onPressed: {
                                                                    windowCard.wasDragged = false;
                                                                    root.draggingWindow = true;
                                                                    root.draggedWindowAddress = modelData.address;
                                                                    root.draggedFromWorkspaceId = modelData.workspaceId;
                                                                }

                                                                onPositionChanged: {
                                                                    if (drag.active)
                                                                        windowCard.wasDragged = true;
                                                                }

                                                                onReleased: {
                                                                    const targetWs = root.hoveredWorkspaceId;
                                                                    const srcWs = root.draggedFromWorkspaceId;
                                                                    const addr = root.draggedWindowAddress;
                                                                    if (addr !== "" && targetWs !== -1 && targetWs !== srcWs) {
                                                                        console.log("[Overview] drag-drop(mouse-release): move " + addr + " → ws " + targetWs);
                                                                        HyprlandService.moveWindowToWorkspace(addr, targetWs);
                                                                    }

                                                                    // Return card visual position back to its layout slot.
                                                                    windowCard.x = 0;
                                                                    windowCard.y = 0;

                                                                    root.draggingWindow = false;
                                                                    root.hoveredWorkspaceId = -1;
                                                                    root.draggedWindowAddress = "";
                                                                    root.draggedFromWorkspaceId = -1;
                                                                }

                                                                onClicked: {
                                                                    // Ignore release that ends a drag gesture
                                                                    if (windowCard.wasDragged || cardDragHandler.active) return;
                                                                    console.log("[Overview] window card clicked: " + modelData.address);
                                                                    HyprlandService.focusWindow(modelData.address);
                                                                    root.close();
                                                                }
                                                            }

                                                            // ── Drag handler ──────
                                                            // target: null — we don't move the card visually,
                                                            // just track drag state to highlight DropAreas.
                                                            DragHandler {
                                                                id: cardDragHandler
                                                                target: null
                                                                dragThreshold: 10

                                                                onActiveChanged: {
                                                                    if (active) {
                                                                        // State is set by MouseArea.onPressed.
                                                                    } else {
                                                                        // State reset is handled by MouseArea.onReleased.
                                                                    }
                                                                }
                                                            }
                                                        } // Rectangle windowCard
                                                    } // Repeater window cards
                                                } // Column cardsColumn
                                            } // Flickable
                                        } // ColumnLayout (workspace content)

                                        // ── Drop target overlay ──────────────────
                                        // Accepts window card drags when draggingWindow is active.
                                        DropArea {
                                            anchors.fill: parent
                                            // Only active while a window is being dragged
                                            enabled: root.draggingWindow

                                            onDropped: drop => {
                                                const targetWs = modelData.id;
                                                const srcWs = root.draggedFromWorkspaceId;
                                                const addr = root.draggedWindowAddress;
                                                if (addr !== "" && targetWs !== -1 && targetWs !== srcWs) {
                                                    console.log("[Overview] drag-drop(onDropped): move " + addr + " → ws " + targetWs);
                                                    // Dispatch move; HyprlandService.windowMoved signal
                                                    // triggers dragDropRefreshTimer via Connections.
                                                    HyprlandService.moveWindowToWorkspace(addr, targetWs);
                                                }
                                            }

                                            onEntered: drag => {
                                                root.hoveredWorkspaceId = modelData.id;
                                            }
                                            onExited: {
                                                if (root.hoveredWorkspaceId === modelData.id)
                                                    root.hoveredWorkspaceId = -1;
                                            }
                                        }

                                        // Click on empty workspace area → switch workspace
                                        MouseArea {
                                            id: wsHoverArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            // Only activate when no window cards are present and not dragging
                                            enabled: workspaceClients.length === 0 && !root.draggingWindow
                                            cursorShape: workspaceClients.length === 0
                                                         ? Qt.PointingHandCursor
                                                         : Qt.ArrowCursor

                                            onClicked: {
                                                if (workspaceClients.length === 0) {
                                                    console.log("[Overview] empty workspace clicked: " + modelData.id);
                                                    HyprlandService.moveToWorkspace(modelData.id);
                                                    root.close();
                                                }
                                            }
                                        }
                                    } // Rectangle workspace column
                                } // Repeater workspaces
                            } // Row
                        } // ScrollView

                        // ── Bottom hint bar ───────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.useGridLayout
                            spacing: 8

                            Rectangle {
                                width: 30
                                height: 24
                                radius: 6
                                color: GlobalState.surface0
                                border.color: GlobalState.surface1
                                border.width: 1
                                opacity: root.workspacePage > 0 ? 1 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: GlobalState.text
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.workspacePage > 0
                                    onClicked: root.goPrevPage()
                                }
                            }

                            Text {
                                text: "Workspaces " + root.pageLabel()
                                color: GlobalState.overlay1
                                font.pixelSize: 11
                            }

                            Rectangle {
                                width: 30
                                height: 24
                                radius: 6
                                color: GlobalState.surface0
                                border.color: GlobalState.surface1
                                border.width: 1
                                opacity: root.workspacePage < root.maxWorkspacePage() ? 1 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    color: GlobalState.text
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.workspacePage < root.maxWorkspacePage()
                                    onClicked: root.goNextPage()
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: [
                                    { key: "Click",  label: "focus window"      },
                                    { key: "Drag",   label: "move to workspace" },
                                    { key: "Empty",  label: "switch workspace"  },
                                    { key: "Esc",    label: "close"             }
                                ]

                                Row {
                                    required property var modelData
                                    spacing: 4

                                    Rectangle {
                                        width:  hintKeyLabel.implicitWidth + 8
                                        height: 18
                                        radius: 4
                                        color:  GlobalState.surface0

                                        Text {
                                            id: hintKeyLabel
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
                    } // ColumnLayout main panel
                } // Rectangle overviewPanel
            } // MouseArea panelArea
        } // Item overviewRoot
    } // PanelWindow
}
