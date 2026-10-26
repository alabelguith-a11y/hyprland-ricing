import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Full-screen power menu (replaces wlogout).
// Keys: arrows/Enter, Esc to close, or the letter shown on each tile.
PanelWindow {
    id: win

    property bool open: false
    signal closeRequested()

    // Edit this list to add/remove/reorder buttons.
    readonly property var entries: [
        { icon: "\uf023", label: "Lock",      key: "l", cmd: Theme.lockCmd },
        { icon: "\uf08b", label: "Log out",   key: "e", cmd: Theme.logoutCmd },
        { icon: "\uf186", label: "Suspend",   key: "s", cmd: Theme.suspendCmd },
        { icon: "\uf021", label: "Reboot",    key: "r", cmd: Theme.rebootCmd },
        { icon: "\uf011", label: "Shut down", key: "p", cmd: Theme.shutdownCmd, danger: true }
    ]
    property int selected: 0

    function run(e) { Quickshell.execDetached(e.cmd); closeRequested(); }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "#d9000000"

    onOpenChanged: if (open) { selected = 0; keys.forceActiveFocus(); }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const n = win.entries.length;
            if (event.key === Qt.Key_Escape) win.closeRequested();
            else if (event.key === Qt.Key_Left)  win.selected = (win.selected + n - 1) % n;
            else if (event.key === Qt.Key_Right) win.selected = (win.selected + 1) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.run(win.entries[win.selected]);
            else {
                const e = win.entries.find(x => x.key === event.text.toLowerCase());
                if (e) win.run(e);
            }
        }

        MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }   // click background = close

        RowLayout {
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: win.entries
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool active: win.selected === index

                    implicitWidth: 130
                    implicitHeight: 150
                    radius: Theme.radius + 4
                    color: active ? "#33ffffff" : "#1affffff"
                    border.width: active ? 2 : 1
                    border.color: active ? (modelData.danger ? Theme.warn : Theme.accent) : Theme.border

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14
                        Lbl {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            font.pixelSize: 38
                            color: tile.active ? (tile.modelData.danger ? Theme.warn : Theme.accent) : Theme.text
                        }
                        Lbl {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.label
                            font.pixelSize: 15
                        }
                        Lbl {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.key.toUpperCase()
                            color: Theme.muted
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.selected = tile.index
                        onClicked: win.run(tile.modelData)
                    }
                }
            }
        }
    }
}
