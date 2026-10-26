import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Dropdown panel. A transparent full-screen overlay catches any click outside
// the panel and closes it, so no compositor focus-grab is needed.
PanelWindow {
    id: pop

    required property Item target
    property int panelWidth: 280
    property double closedAt: 0
    property real anchorRight: 0
    property real anchorCenter: 0
    property bool centered: true    // true = center under the target, false = right-align to it
    default property alias content: col.data

    function close() { visible = false; closedAt = Date.now(); }
    function toggle() {
        if (visible) close();
        else if (Date.now() - closedAt > 250) {
            anchorRight = target.mapToItem(null, target.width, 0).x;
            anchorCenter = target.mapToItem(null, target.width / 2, 0).x;
            visible = true;
        }
    }

    visible: false
    screen: target.QsWindow.window ? target.QsWindow.window.screen : null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: pop.close()
    }

    Rectangle {
        x: Math.max(8, Math.min(pop.width - width - 8,
                                pop.centered ? pop.anchorCenter - width / 2 : pop.anchorRight - width))
        y: Theme.barHeight + 2
        width: pop.panelWidth
        height: Math.min(col.implicitHeight + 24, pop.height - Theme.barHeight - 24)   // capped; scrolls beyond this
        radius: Theme.radius
        color: Theme.popupBg
        border.color: Theme.border
        border.width: 1

        MouseArea { anchors.fill: parent }   // clicks on the panel itself don't close it

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: flick.width
                spacing: 6
            }
        }

        Rectangle {   // scroll indicator
            visible: flick.contentHeight > flick.height
            x: parent.width - 5
            y: 12 + flick.visibleArea.yPosition * flick.height
            width: 3
            height: Math.max(20, flick.visibleArea.heightRatio * flick.height)
            radius: 1.5
            color: Theme.muted
        }
    }
}
