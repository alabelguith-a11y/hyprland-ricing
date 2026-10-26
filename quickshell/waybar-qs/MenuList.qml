import Quickshell
import QtQuick
import QtQuick.Layouts

// Renders a tray/dbusmenu (nm-applet, app tray icons...) with the bar's theme.
ColumnLayout {
    id: list

    property var menuHandle: null
    signal done()

    Layout.fillWidth: true
    spacing: 2

    QsMenuOpener { id: opener; menu: list.menuHandle }

    Repeater {
        model: opener.children
        delegate: ColumnLayout {
            id: item
            required property var modelData
            property bool expanded: false
            Layout.fillWidth: true
            spacing: 2

            Rectangle {   // separator
                visible: item.modelData.isSeparator
                Layout.fillWidth: true
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                implicitHeight: 1
                color: Theme.border
            }

            Rectangle {
                visible: !item.modelData.isSeparator
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 6
                color: mouse.containsMouse && item.modelData.enabled ? Theme.hover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Lbl {
                        Layout.preferredWidth: 14
                        color: Theme.accent
                        text: item.modelData.buttonType !== QsMenuButtonType.None
                              && item.modelData.checkState === Qt.Checked ? "\uf00c" : ""
                    }
                    Lbl {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: item.modelData.text
                        color: item.modelData.enabled ? Theme.text : Theme.muted
                    }
                    Lbl {
                        visible: item.modelData.hasChildren
                        color: Theme.muted
                        text: item.expanded ? "\uf078" : "\uf054"
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (item.modelData.hasChildren) item.expanded = !item.expanded;
                        else if (item.modelData.enabled) { item.modelData.triggered(); list.done(); }
                    }
                }
            }

            // submenu (e.g. nm-applet's "More networks")
            Loader {
                id: sub
                active: item.expanded && item.modelData.hasChildren
                source: "MenuList.qml"
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.preferredHeight: sub.item ? sub.item.implicitHeight : 0
                onLoaded: {
                    sub.item.menuHandle = item.modelData;
                    sub.item.width = Qt.binding(() => sub.width);
                    sub.item.done.connect(list.done);
                }
            }
        }
    }
}
