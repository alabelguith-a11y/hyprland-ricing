import QtQuick

// Simple draggable slider. Emits moved(v) with v in 0..1; the parent applies it.
Item {
    id: s

    property real value: 0
    property bool dimmed: false
    signal moved(real v)

    implicitHeight: 20

    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.hover

        Rectangle {
            width: parent.width * s.clamped
            height: parent.height
            radius: 3
            color: s.dimmed ? Theme.muted : Theme.accent
        }
    }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: (s.width - width) * s.clamped
        color: Theme.text
    }

    MouseArea {
        anchors.fill: parent
        function setFrom(mx) { s.moved(Math.max(0, Math.min(1, mx / width))); }
        onPressed: mouse => setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x); }
    }
}
