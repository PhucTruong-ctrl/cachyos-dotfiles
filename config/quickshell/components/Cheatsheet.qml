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

    function formatBinding(keybind) {
        const parts = [];

        if (keybind.submap && keybind.submap.length > 0) {
            parts.push("[" + keybind.submap + "]");
        }

        if (keybind.mods && keybind.mods.length > 0) {
            parts.push(keybind.mods.join(" + "));
        }

        if (keybind.key && keybind.key.length > 0) {
            parts.push(keybind.key);
        }

        return parts.join(" + ");
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
                    color: Qt.rgba(0, 0, 0, 0.78)
                }
            }

            Rectangle {
                id: cheatsheetCard
                anchors.centerIn: parent
                width: Math.min(parent.width - 96, 1200)
                height: Math.min(parent.height - 96, 820)
                radius: Appearance.panelRadius + 4
                color: Qt.rgba(GlobalState.base.r, GlobalState.base.g, GlobalState.base.b, Appearance.panelOpacity)
                border.color: GlobalState.matugenPrimary
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Keyboard shortcuts"
                            color: GlobalState.matugenPrimary
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

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: GlobalState.surface0
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
                            spacing: 12

                            Repeater {
                                model: root.groupedSections

                                Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: sectionLayout.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(GlobalState.mantle.r, GlobalState.mantle.g, GlobalState.mantle.b, 0.82)
                                    border.color: GlobalState.surface0
                                    border.width: 1

                                    ColumnLayout {
                                        id: sectionLayout
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                text: modelData.section
                                                color: GlobalState.text
                                                font.pixelSize: 18
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.keybinds.length + " binds"
                                                color: GlobalState.overlay1
                                                font.pixelSize: 11
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: GlobalState.surface1
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: modelData.keybinds

                                                Rectangle {
                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    radius: 10
                                                    color: bindingArea.containsMouse ? GlobalState.surface0 : GlobalState.base
                                                    border.color: bindingArea.containsMouse ? GlobalState.matugenPrimary : GlobalState.surface1
                                                    border.width: 1
                                                    implicitHeight: bindingRow.implicitHeight + 18

                                                    Behavior on color {
                                                        ColorAnimation { duration: Appearance.popupFade }
                                                    }

                                                    Behavior on border.color {
                                                        ColorAnimation { duration: Appearance.popupFade }
                                                    }

                                                    RowLayout {
                                                        id: bindingRow
                                                        anchors.fill: parent
                                                        anchors.margins: 9
                                                        spacing: 12

                                                        Rectangle {
                                                            Layout.alignment: Qt.AlignTop
                                                            Layout.maximumWidth: Math.max(180, bindingRow.width * 0.42)
                                                            radius: 8
                                                            color: GlobalState.surface0
                                                            border.color: GlobalState.surface1
                                                            border.width: 1
                                                            implicitWidth: Math.min(bindingKeyLabel.implicitWidth + 18, Math.max(180, bindingRow.width * 0.42))
                                                            implicitHeight: bindingKeyLabel.implicitHeight + 10

                                                            Text {
                                                                id: bindingKeyLabel
                                                                anchors.centerIn: parent
                                                                width: parent.width - 18
                                                                text: root.formatBinding(modelData)
                                                                color: GlobalState.matugenPrimary
                                                                font.pixelSize: 12
                                                                font.bold: true
                                                                wrapMode: Text.WrapAnywhere
                                                                horizontalAlignment: Text.AlignHCenter
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
                                                                font.pixelSize: 13
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
