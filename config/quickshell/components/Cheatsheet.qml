import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services"

Scope {
    id: root

    property var groupedSections: groupKeybindsBySection(KeybindsService.keybinds)
    function groupKeybindsBySection(keybinds) {
        const sections = [];
        const sectionIndexes = {};

        for (let i = 0; i < keybinds.length; i++) {
            const keybind = keybinds[i];
            const sectionName = keybind.section && keybind.section.length > 0 ? keybind.section : "General";
            let sectionIndex = sectionIndexes[sectionName];

            if (sectionIndex === undefined) {
                sectionIndex = sections.length;
                sectionIndexes[sectionName] = sectionIndex;
                sections.push({ section: sectionName, keybinds: [] });
            }

            sections[sectionIndex].keybinds.push(keybind);
        }

        return sections;
    }

    function bindingTokens(keybind) {
        const tokens = [];

        if (keybind.submap && keybind.submap.length > 0) {
            tokens.push("[" + keybind.submap + "]");
        }

        if (keybind.mods && keybind.mods.length > 0) {
            for (let i = 0; i < keybind.mods.length; i++) {
                tokens.push(keybind.mods[i]);
            }
        }

        if (keybind.key && keybind.key.length > 0) {
            tokens.push(keybind.key);
        }

        return tokens;
    }

    function close() {
        if (PopupStateService.openPopupId === "cheatsheet") {
            PopupStateService.closeAll();
        }
    }

    IpcHandler {
        target: "toggle-cheatsheet"

        function toggle(): void { PopupStateService.toggleExclusive("cheatsheet") }
        function show(): void { PopupStateService.openExclusive("cheatsheet") }
        function hide(): void {
            if (PopupStateService.openPopupId === "cheatsheet") PopupStateService.closeAll()
        }
    }

    Connections {
        target: PopupStateService

        function onOpenPopupIdChanged() {
            cheatsheetWindow.visible = (PopupStateService.openPopupId === "cheatsheet")
            if (cheatsheetWindow.visible) {
                cheatsheetRoot.forceActiveFocus()
            }
        }
    }

    PanelWindow {
        id: cheatsheetWindow

        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-cheatsheet"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: cheatsheetRoot
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: {
                PopupStateService.closeAll()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: PopupStateService.closeAll()

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.50)
                }
            }

            Rectangle {
                id: cheatsheetCard
                anchors.centerIn: parent
                width: Math.min(parent.width - 96, 1200)
                height: Math.min(parent.height - 96, 820)
                radius: Appearance.panelRadius + 4
                color: Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
                border.color: GlobalState.surface0
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Keyboard shortcuts"
                            color: GlobalState.text
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            radius: 6
                            color: GlobalState.surface0
                            implicitWidth: closeHintLabel.implicitWidth + 16
                            implicitHeight: closeHintLabel.implicitHeight + 10

                            Text {
                                id: closeHintLabel
                                anchors.centerIn: parent
                                text: "Esc to close"
                                color: GlobalState.overlay1
                                font.pixelSize: 12
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.groupedSections.length === 0
                        text: "No keybind descriptions found in Hyprland bindd entries."
                        color: GlobalState.overlay1
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }

                    Flickable {
                        id: cheatsheetFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: sectionsColumn.implicitHeight

                        ColumnLayout {
                            id: sectionsColumn
                            width: cheatsheetFlickable.width
                            spacing: 18

                            Repeater {
                                model: root.groupedSections

                                Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: sectionLayout.implicitHeight + 28
                                    radius: 14
                                    color: Qt.rgba(GlobalState.mantle.r, GlobalState.mantle.g, GlobalState.mantle.b, 0.50)
                                    border.color: GlobalState.surface0
                                    border.width: 1

                                    ColumnLayout {
                                        id: sectionLayout
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                text: modelData.section
                                                color: GlobalState.text
                                                font.pixelSize: 20
                                                font.weight: Font.DemiBold
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.keybinds.length + " binds"
                                                color: GlobalState.overlay1
                                                font.pixelSize: 11
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Repeater {
                                                model: modelData.keybinds

                                                Rectangle {
                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    radius: 12
                                                    color: bindingArea.containsMouse ? Qt.rgba(GlobalState.surface0.r, GlobalState.surface0.g, GlobalState.surface0.b, 0.62) : Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, 0.72)
                                                    border.color: bindingArea.containsMouse ? GlobalState.surface1 : GlobalState.surface0
                                                    border.width: 1
                                                    implicitHeight: bindingGrid.implicitHeight + 18

                                                    Behavior on color {
                                                        ColorAnimation { duration: Appearance.popupFade }
                                                    }

                                                    Behavior on border.color {
                                                        ColorAnimation { duration: Appearance.popupFade }
                                                    }

                                                    GridLayout {
                                                        id: bindingGrid
                                                        anchors.fill: parent
                                                        anchors.margins: 9
                                                        columns: 2
                                                        columnSpacing: 14
                                                        rowSpacing: 8

                                                        Item {
                                                            Layout.alignment: Qt.AlignTop
                                                            Layout.maximumWidth: Math.max(180, bindingGrid.width * 0.42)
                                                            Layout.minimumWidth: 0
                                                            implicitWidth: Math.min(bindingFlow.implicitWidth, Math.max(180, bindingGrid.width * 0.42))
                                                            implicitHeight: bindingFlow.implicitHeight

                                                            Flow {
                                                                id: bindingFlow
                                                                width: parent.width
                                                                spacing: 6

                                                                Repeater {
                                                                    model: root.bindingTokens(modelData)

                                                                    Rectangle {
                                                                        required property string modelData

                                                                        readonly property int extraBottomBorderWidth: 2
                                                                        radius: 6
                                                                        color: GlobalState.surface1
                                                                        implicitWidth: keycapLabel.implicitWidth + 18
                                                                        implicitHeight: keycapLabel.implicitHeight + 10 + extraBottomBorderWidth

                                                                        Rectangle {
                                                                            anchors {
                                                                                top: parent.top
                                                                                left: parent.left
                                                                                right: parent.right
                                                                                bottom: parent.bottom
                                                                                leftMargin: 1
                                                                                rightMargin: 1
                                                                                topMargin: 1
                                                                                bottomMargin: 1 + parent.extraBottomBorderWidth
                                                                            }
                                                                            radius: parent.radius - 1
                                                                            color: Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, 0.94)

                                                                            Text {
                                                                                id: keycapLabel
                                                                                anchors.centerIn: parent
                                                                                text: modelData
                                                                                color: GlobalState.text
                                                                                font.family: "monospace"
                                                                                font.pixelSize: 12
                                                                                font.bold: true
                                                                                wrapMode: Text.WrapAnywhere
                                                                                horizontalAlignment: Text.AlignHCenter
                                                                                renderType: Text.NativeRendering
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            spacing: 4

                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                text: modelData.description
                                                                color: GlobalState.text
                                                                font.pixelSize: 12
                                                                renderType: Text.NativeRendering
                                                                wrapMode: Text.Wrap
                                                            }

                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                visible: modelData.submap && modelData.submap.length > 0
                                                                text: "Submap: " + modelData.submap
                                                                color: GlobalState.overlay1
                                                                font.pixelSize: 11
                                                                wrapMode: Text.Wrap
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: bindingArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.ArrowCursor
                                                        onClicked: {
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
