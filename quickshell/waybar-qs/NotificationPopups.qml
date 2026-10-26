// Notification popup cards (+ volume/brightness OSD). Data comes from NotifStore.
// Test:  notify-send "Hello" "World"
//        notify-send -a VolumeOSD "Volume" "45%"
//        notify-send -a BrightnessOSD "Brightness" "60%"
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ---- palette (change colors here) ----
    readonly property color cBg:      "#cc0a1222"   // card background (alpha in the color, not `opacity`)
    readonly property color cBorder:  "#5fc8d4"
    readonly property color cCrit:    "#f38ba8"
    readonly property color cTitle:   "#d3e3ef"
    readonly property color cBody:    "#a6b8c8"
    readonly property color cTrack:   "#1f3452"
    readonly property color cButton:  "#14213a"
    readonly property int   cardWidth: 360
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int   fallbackTimeout: 5      // seconds, when the sender gives none
    readonly property int   maxTimeout: 5         // hard cap in seconds, applies to every notification
    readonly property bool  pauseOnHover: false     // true = hovering keeps the card (can exceed the cap)

    PanelWindow {
        anchors { top: true; right: true }
        margins { top: Theme.barHeight + 8; right: 12 }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay      // above fullscreen windows
        WlrLayershell.namespace: "qs-notifications"
        color: "transparent"
        implicitWidth: root.cardWidth
        implicitHeight: list.implicitHeight
        visible: list.implicitHeight > 0

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 8

            Repeater {
                model: NotifStore.server.trackedNotifications

                delegate: Rectangle {
                    id: card
                    required property var modelData

                    readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical
                    // OSD cards from volumebar.sh / brightnessbar.sh: body is "45%" or "Muted"
                    readonly property bool isVolume: modelData.appName === "VolumeOSD"
                    readonly property bool isBrightness: modelData.appName === "BrightnessOSD"
                    readonly property bool isOsd: isVolume || isBrightness
                    readonly property bool isMuted: modelData.body === "Muted"
                    readonly property int level: Math.min(parseInt(modelData.body) || 0, 100)
                    readonly property string osdGlyph: isBrightness ? "\uf185"
                        : isMuted || level === 0 ? "\uf026" : level >= 50 ? "\uf028" : "\uf027"

                    visible: !NotifStore.dnd || isOsd     // Do Not Disturb hides everything but OSDs
                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 24
                    radius: 12
                    color: root.cBg
                    border.width: 2
                    border.color: isCritical ? root.cCrit : root.cBorder

                    // ---- entry animation (replaced notifications reuse this card, so no re-animate) ----
                    opacity: 0
                    transform: Translate { id: slide; x: 40 }
                    Component.onCompleted: enter.start()
                    ParallelAnimation {
                        id: enter
                        NumberAnimation { target: card;  property: "opacity"; to: 1; duration: 180 }
                        NumberAnimation { target: slide; property: "x";       to: 0; duration: 180; easing.type: Easing.OutCubic }
                    }

                    // ---- auto-expire, never longer than root.maxTimeout (critical included) ----
                    HoverHandler { id: hover }
                    Timer {
                        id: expireTimer
                        interval: Math.min(card.modelData.expireTimeout > 0
                                           ? card.modelData.expireTimeout : root.fallbackTimeout,
                                           root.maxTimeout) * 1000
                        running: !(root.pauseOnHover && hover.hovered)
                        onTriggered: card.modelData.expire()
                    }
                    // A replaced notification (notify-send -r) updates this same card,
                    // so restart the countdown instead of using the original one.
                    Connections {
                        target: card.modelData
                        function onBodyChanged()    { expireTimer.restart() }
                        function onSummaryChanged() { expireTimer.restart() }
                    }

                    // Click anywhere to dismiss (action buttons sit above this)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.modelData.dismiss()
                    }

                    RowLayout {
                        id: content
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        Image {
                            visible: !card.isOsd && status === Image.Ready
                            source: card.modelData.image !== ""
                                    ? card.modelData.image
                                    : (card.modelData.appIcon !== ""
                                       ? Quickshell.iconPath(card.modelData.appIcon, true) : "")
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignTop
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {   // OSD glyph (volume / brightness)
                            visible: card.isOsd
                            text: card.osdGlyph
                            color: card.isMuted ? root.cBody : root.cBorder
                            font { family: root.fontFamily; pixelSize: 32 }
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignTop
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: card.modelData.summary
                                color: root.cTitle
                                font { bold: true; pixelSize: 14 }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: card.modelData.body
                                textFormat: Text.StyledText
                                color: root.cBody
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                visible: text !== ""
                            }

                            Rectangle {   // level bar (OSD only)
                                visible: card.isOsd
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: root.cTrack
                                Rectangle {
                                    width: parent.width * (card.isMuted ? 0 : card.level / 100)
                                    height: parent.height
                                    radius: 3
                                    color: root.cBorder
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                }
                            }

                            // Action buttons (skips the invisible "default" action)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: card.modelData.actions.length > 0 && !card.isOsd

                                Repeater {
                                    model: card.modelData.actions
                                    delegate: Rectangle {
                                        id: btn
                                        required property var modelData
                                        readonly property var act: modelData

                                        visible: act.identifier !== "default"
                                        implicitWidth: label.implicitWidth + 20
                                        implicitHeight: 26
                                        radius: 8
                                        color: btnArea.containsMouse ? root.cBorder : root.cButton
                                        border { width: 1; color: root.cTrack }

                                        Text {
                                            id: label
                                            anchors.centerIn: parent
                                            text: btn.act.text
                                            color: btnArea.containsMouse ? "#0a1222" : root.cTitle
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            id: btnArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: btn.act.invoke()
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
