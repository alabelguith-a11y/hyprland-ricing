import QtQuick
import QtQuick.Layouts

// A rounded "island" container; children are laid out in a row.
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing

    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 24
    radius: Theme.radius
    color: Theme.bg
    border.color: Theme.border
    border.width: 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 14
    }
}
