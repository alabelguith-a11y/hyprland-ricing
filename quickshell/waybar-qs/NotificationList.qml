import Quickshell
import QtQuick
import QtQuick.Layouts

// Notification history. Put inside a PopupPanel (it scrolls when long).
ColumnLayout {
    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Lbl { text: "Notifications"; font.bold: true; Layout.fillWidth: true }

        Lbl {   // Do Not Disturb
            text: (NotifStore.dnd ? "\uf1f6" : "\uf0f3") + "  DND"
            color: NotifStore.dnd ? Theme.accent : Theme.muted
            MouseArea { anchors.fill: parent; onClicked: NotifStore.dnd = !NotifStore.dnd }
        }
        Lbl {
            text: "\uf1f8  Clear"
            color: Theme.muted
            MouseArea { anchors.fill: parent; onClicked: NotifStore.clear() }
        }
    }

    Lbl {
        visible: NotifStore.history.count === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        Layout.bottomMargin: 12
        text: "No notifications"
        color: Theme.muted
    }

    Repeater {
        model: NotifStore.history
        delegate: Rectangle {
            id: entry
            required property int index
            required property string appName
            required property string summary
            required property string body
            required property string image
            required property string appIcon
            required property double time

            Layout.fillWidth: true
            implicitHeight: row.implicitHeight + 16
            radius: 8
            color: Theme.hover

            RowLayout {
                id: row
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 10

                Image {
                    visible: status === Image.Ready
                    source: entry.image !== "" ? entry.image
                            : entry.appIcon !== "" ? Quickshell.iconPath(entry.appIcon, true) : ""
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Lbl {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Theme.muted
                        font.pixelSize: 11
                        text: entry.appName + "  ·  " + Qt.formatDateTime(new Date(entry.time), "HH:mm")
                    }
                    Lbl {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.bold: true
                        text: entry.summary
                    }
                    Lbl {
                        visible: text !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        color: Theme.muted
                        font.pixelSize: 12
                        text: entry.body
                    }
                }

                Lbl {
                    text: "\uf00d"
                    color: Theme.muted
                    Layout.alignment: Qt.AlignTop
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: NotifStore.remove(entry.index)
                    }
                }
            }
        }
    }
}
