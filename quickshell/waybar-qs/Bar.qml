//@ pragma UseQApplication
// Ryoku-style "islands" bar for Quickshell (Hyprland), with:
//   - nm-applet network menu     - Bluetooth panel
//   - power menu                 - settings button (HyprMod)
// Colors, fonts and launched commands live in Theme.qml.

import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property bool powerOpen: false
    property int cpuPct: 0
    property int memPct: 0
    property string netText: ""
    property string netIcon: "\udb82\udd2f"   // wifi-off

    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    // Tray entries that already have their own button on the bar.
    function hiddenInTray(item) {
        const k = ((item.id ?? "") + " " + (item.title ?? "")).toLowerCase();
        return /nm-applet|network|blueman|bluetooth/.test(k);
    }

    // nm-applet provides the network menu through the tray (started once).
    Process {
        running: true
        command: ["sh", "-c", "pgrep -x nm-applet >/dev/null || exec nm-applet --indicator"]
    }

    // CPU + RAM
    Process {
        id: sysProc
        command: ["sh", "-c",
            "read a u n s i rest </proc/stat; sleep 0.4; read b u2 n2 s2 i2 rest </proc/stat; " +
            "cpu=$(( 100*((u2+n2+s2)-(u+n+s)) / ((u2+n2+s2+i2)-(u+n+s+i)) )); " +
            "mem=$(free | awk '/Mem/{printf \"%d\", $3*100/$2}'); echo \"$cpu $mem\""]
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim().split(" ");
                root.cpuPct = parseInt(p[0]) || 0;
                root.memPct = parseInt(p[1]) || 0;
            }
        }
    }

    // Active connection label
    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION dev | grep ':connected' | grep -v loopback | head -1"]
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim().split(":");
                if (p.length < 3 || p[0] === "") { root.netIcon = "\udb82\udd2f"; root.netText = "offline"; return; }
                root.netIcon = p[0] === "wifi" ? "\udb81\udda9" : "\udb80\ude00";
                root.netText = p.slice(2).join(":");
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { sysProc.running = true; netProc.running = true; }
    }

    // Power menu on every screen; toggle from a keybind with:
    //   qs -c ryoku-bar ipc call power toggle
    IpcHandler {
        target: "power"
        function toggle(): void { root.powerOpen = !root.powerOpen; }
        function open(): void   { root.powerOpen = true; }
        function close(): void  { root.powerOpen = false; }
    }
    Variants {
        model: Quickshell.screens
        PowerMenu {
            required property var modelData
            screen: modelData
            open: root.powerOpen
            onCloseRequested: root.powerOpen = false
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.barHeight
            exclusiveZone: Theme.barHeight
            color: "transparent"
            WlrLayershell.namespace: "qs-bar"

            Item {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                // ================= LEFT =================
                Island {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Lbl {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.rightMargin: 4
                        IconImage {
                            source: Qt.resolvedUrl("./hyprland.svg")
                            implicitSize: 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(Theme.launcherCmd)
                        }
                    }
                    Lbl {
                        Layout.maximumWidth: 220
                        elide: Text.ElideRight
                        color: Theme.muted
                        text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : "Desktop"
                    }
                    // ---- Media ----
                    Lbl {
                        id: media
                        readonly property var player: {
                            const ps = Mpris.players.values;
                            return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
                        }
                        visible: player !== null && (player.trackTitle ?? "") !== ""
                        Layout.maximumWidth: 220
                        elide: Text.ElideRight
                        color: Theme.accent
                        text: player ? ((player.isPlaying ? "\uf04b " : "\uf04c ") + player.trackTitle) : ""
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                if (!media.player) return;
                                if (mouse.button === Qt.LeftButton) media.player.togglePlaying();
                                else if (mouse.button === Qt.RightButton) media.player.next();
                                else media.player.previous();
                            }
                        }
                    }
                }

                // ================= CENTER: workspaces =================
                Island {
                    id: wsIsland
                    anchors.centerIn: parent
                    spacing: 6
                    // ---- Clock ----
                    Lbl {
                        id: dateBtn
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: Theme.accent
                        font.bold: true

                        MouseArea { anchors.fill: parent; onClicked: calPop.toggle() }

                        PopupPanel {
                            id: calPop
                            target: wsIsland          // centers under the whole workspace island
                            centered: true
                            panelWidth: 280
                            onVisibleChanged: if (visible) cal.reset()
                            CalendarView { id: cal }
                        }
                    }
                    Repeater {
                        model: Theme.numWorkspaces
                        delegate: Rectangle {
                            id: ws
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
                            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                            implicitHeight: 10
                            implicitWidth: focused ? 28 : 10
                            radius: 5
                            color: focused ? Theme.accent : occupied ? Theme.text : Theme.muted
                            opacity: focused || occupied ? 1.0 : 0.4
                            Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: Hyprland.dispatch("workspace " + ws.wsId)
                            }
                        }
                    }
                    // ---- Clock ----
                    Lbl {
                        id: timeBtn
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.accent
                        font.bold: true

                        MouseArea { anchors.fill: parent; onClicked: clockPop.toggle() }

                        PopupPanel {
                            id: clockPop
                            target: wsIsland
                            centered: true
                            panelWidth: 240
                            onVisibleChanged: clockView.active = visible
                            ClockView { id: clockView }
                        }
                    }
                }

                // ================= RIGHT =================
                Island {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    // ---- Tray (nm-applet / blueman hidden, they have their own buttons) ----
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                id: trayItem
                                required property var modelData
                                visible: !root.hiddenInTray(modelData)
                                implicitWidth: 18
                                implicitHeight: 18

                                Image {
                                    anchors.fill: parent
                                    source: trayItem.modelData.icon
                                    sourceSize: Qt.size(36, 36)
                                    smooth: true
                                }
                                PopupPanel {
                                    id: trayMenu
                                    target: trayItem
                                    panelWidth: 240
                                    MenuList { menuHandle: trayItem.modelData.menu; onDone: trayMenu.close() }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) trayItem.modelData.activate();
                                        else if (mouse.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate();
                                        else if (trayItem.modelData.hasMenu) trayMenu.toggle();
                                    }
                                }
                            }
                        }
                    }
                            // ---- Clipboard ----
                    Lbl {
                        text: "\uf0ea"
                        font.pixelSize: 16
                        MouseArea { anchors.fill: parent; onClicked: clipboard.open = !clipboard.open }
                    }
                                        // ---- Notifications ----
                    Lbl {
                        id: bellBtn
                        text: (NotifStore.dnd ? "\uf1f6" : "\uf0f3") + (NotifStore.unread > 0 ? " " + NotifStore.unread : "")
                        color: NotifStore.unread > 0 ? Theme.accent : Theme.text
                        font.pixelSize: 16
                    
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) NotifStore.dnd = !NotifStore.dnd;
                                else notifPop.toggle();
                            }
                        }
                    
                        PopupPanel {
                            id: notifPop
                            target: bellBtn
                            panelWidth: 340
                            onVisibleChanged: if (visible) NotifStore.unread = 0
                            NotificationList {}
                        }
                    }
                    // ---- CPU / RAM ----
                    Lbl { text: "\uf2db " + root.cpuPct + "%"; color: root.cpuPct > 85 ? Theme.warn : Theme.text }
                    Lbl { text: "\uefc5 " + root.memPct + "%"; color: root.memPct > 85 ? Theme.warn : Theme.text }

                    // ---- Network: opens nm-applet's menu ----
                    Lbl {
                        id: netBtn
                        readonly property var nmItem: SystemTray.items.values.find(i =>
                            /nm-applet|network/.test(((i.id ?? "") + " " + (i.title ?? "")).toLowerCase())) ?? null
                        text: root.netIcon + " " + root.netText
                        Layout.maximumWidth: 140
                        elide: Text.ElideRight

                        PopupPanel {
                            id: netPop
                            target: netBtn
                            panelWidth: 280
                            MenuList { menuHandle: netBtn.nmItem ? netBtn.nmItem.menu : null; onDone: netPop.close() }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton || !netBtn.nmItem || !netBtn.nmItem.hasMenu)
                                    Quickshell.execDetached(Theme.netEditorCmd);   // full editor
                                else
                                    netPop.toggle();                                // nm-applet menu
                            }
                        }
                    }

                    // ---- Bluetooth ----
                    Lbl {
                        id: btBtn
                        readonly property var adapter: Bluetooth.defaultAdapter
                        readonly property bool anyConnected: adapter && adapter.devices.values.some(d => d.connected)
                        text: !adapter || !adapter.enabled ? "\udb80\udcb2"
                              : anyConnected ? "\udb80\udcb1" : "\udb80\udcaf"
                        color: !adapter || !adapter.enabled ? Theme.muted
                               : anyConnected ? Theme.accent : Theme.text
                        font.pixelSize: 16

                        MouseArea { anchors.fill: parent; onClicked: btPop.toggle() }

                        PopupPanel {
                            id: btPop
                            target: btBtn
                            panelWidth: 300

                            RowLayout {
                                Layout.fillWidth: true
                                Lbl { text: "Bluetooth"; font.bold: true; Layout.fillWidth: true }
                                Rectangle {   // on/off switch
                                    implicitWidth: 40; implicitHeight: 20; radius: 10
                                    color: btBtn.adapter && btBtn.adapter.enabled ? Theme.accent : Theme.muted
                                    Rectangle {
                                        width: 16; height: 16; radius: 8; y: 2
                                        x: btBtn.adapter && btBtn.adapter.enabled ? 22 : 2
                                        color: "#131313"
                                        Behavior on x { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: if (btBtn.adapter) btBtn.adapter.enabled = !btBtn.adapter.enabled
                                    }
                                }
                            }

                            Lbl {
                                visible: !btBtn.adapter
                                text: "No Bluetooth adapter found"
                                color: Theme.muted
                            }

                            Repeater {
                                model: btBtn.adapter ? btBtn.adapter.devices : null
                                delegate: Rectangle {
                                    id: dev
                                    required property var modelData
                                    visible: modelData.paired || modelData.connected
                                             || (btBtn.adapter && btBtn.adapter.discovering)
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: 6
                                    color: devMouse.containsMouse ? Theme.hover : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        Lbl {
                                            text: dev.modelData.name || dev.modelData.address
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            color: dev.modelData.connected ? Theme.accent : Theme.text
                                        }
                                        Lbl {
                                            color: Theme.muted
                                            text: (dev.modelData.batteryAvailable
                                                   ? Math.round(dev.modelData.battery * 100) + "%  " : "")
                                                  + (dev.modelData.connected ? "connected"
                                                     : dev.modelData.paired ? "paired" : "new")
                                        }
                                    }
                                    MouseArea {
                                        id: devMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (!dev.modelData.paired) dev.modelData.pair();
                                            else dev.modelData.connected = !dev.modelData.connected;
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30; radius: 6
                                    color: scanMouse.containsMouse ? Theme.hover : "transparent"
                                    border.color: Theme.border
                                    Lbl {
                                        anchors.centerIn: parent
                                        text: btBtn.adapter && btBtn.adapter.discovering ? "Stop scan" : "Scan"
                                    }
                                    MouseArea {
                                        id: scanMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: if (btBtn.adapter) btBtn.adapter.discovering = !btBtn.adapter.discovering
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30; radius: 6
                                    color: mgrMouse.containsMouse ? Theme.hover : "transparent"
                                    border.color: Theme.border
                                    Lbl { anchors.centerIn: parent; text: "Manager" }
                                    MouseArea {
                                        id: mgrMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { btPop.visible = false; Quickshell.execDetached(Theme.btManagerCmd); }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Volume: click = panel, wheel = adjust, middle = mute ----
                    Lbl {
                        id: volBtn
                        readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
                        readonly property int pct: audio ? Math.round(audio.volume * 100) : 0
                        text: !audio ? "\uf026 --"
                              : (audio.muted || pct === 0 ? "\uf026 " : pct < 50 ? "\uf027 " : "\uf028 ") + pct + "%"
                        color: audio && audio.muted ? Theme.muted : Theme.text

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) volPop.toggle();
                                else if (mouse.button === Qt.MiddleButton && volBtn.audio) volBtn.audio.muted = !volBtn.audio.muted;
                                else if (mouse.button === Qt.RightButton) Quickshell.execDetached(Theme.mixerCmd);
                            }
                            onWheel: wheel => {
                                if (!volBtn.audio) return;
                                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                volBtn.audio.volume = Math.max(0, Math.min(1, volBtn.audio.volume + step));
                            }
                        }

                        PopupPanel {
                            id: volPop
                            target: volBtn
                            panelWidth: 300

                            // Output
                            RowLayout {
                                Layout.fillWidth: true
                                Lbl {
                                    text: volBtn.audio && volBtn.audio.muted ? "\uf026" : "\uf028"
                                    color: volBtn.audio && volBtn.audio.muted ? Theme.muted : Theme.accent
                                    Layout.preferredWidth: 20
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: if (volBtn.audio) volBtn.audio.muted = !volBtn.audio.muted
                                    }
                                }
                                VolumeSlider {
                                    Layout.fillWidth: true
                                    value: volBtn.audio ? volBtn.audio.volume : 0
                                    dimmed: volBtn.audio ? volBtn.audio.muted : true
                                    onMoved: v => { if (volBtn.audio) { volBtn.audio.volume = v; volBtn.audio.muted = false; } }
                                }
                                Lbl { text: volBtn.pct + "%"; color: Theme.muted; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
                            }

                            // Microphone
                            RowLayout {
                                Layout.fillWidth: true
                                readonly property var mic: Pipewire.defaultAudioSource?.audio ?? null
                                visible: mic !== null
                                Lbl {
                                    text: parent.mic && parent.mic.muted ? "\uf131" : "\uf130"
                                    color: parent.mic && parent.mic.muted ? Theme.muted : Theme.accent
                                    Layout.preferredWidth: 20
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: if (parent.parent.mic) parent.parent.mic.muted = !parent.parent.mic.muted
                                    }
                                }
                                VolumeSlider {
                                    Layout.fillWidth: true
                                    value: parent.mic ? parent.mic.volume : 0
                                    dimmed: parent.mic ? parent.mic.muted : true
                                    onMoved: v => { if (parent.mic) { parent.mic.volume = v; parent.mic.muted = false; } }
                                }
                                Lbl {
                                    text: (parent.mic ? Math.round(parent.mic.volume * 100) : 0) + "%"
                                    color: Theme.muted
                                    Layout.preferredWidth: 38
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            // Output device picker
                            Lbl { text: "Output"; color: Theme.muted; font.pixelSize: 11 }
                            Repeater {
                                model: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
                                delegate: Rectangle {
                                    id: sinkRow
                                    required property var modelData
                                    readonly property bool current: Pipewire.defaultAudioSink === modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    radius: 6
                                    color: sinkMouse.containsMouse ? Theme.hover : "transparent"
                                    Lbl {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        elide: Text.ElideRight
                                        text: (sinkRow.current ? "\uf00c  " : "     ")
                                              + (sinkRow.modelData.description || sinkRow.modelData.name)
                                        color: sinkRow.current ? Theme.accent : Theme.text
                                    }
                                    MouseArea {
                                        id: sinkMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: Pipewire.preferredDefaultAudioSink = sinkRow.modelData
                                    }
                                }
                            }

                            // Open full mixer
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 30; radius: 6
                                color: mixMouse.containsMouse ? Theme.hover : "transparent"
                                border.color: Theme.border
                                Lbl { anchors.centerIn: parent; text: "Mixer" }
                                MouseArea {
                                    id: mixMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { volPop.visible = false; Quickshell.execDetached(Theme.mixerCmd); }
                                }
                            }
                        }
                    }

                    // ---- Battery (laptops only) ----
                    Lbl {
                        readonly property var bat: UPower.displayDevice
                        readonly property int pct: bat ? Math.round(bat.percentage * 100) : 0
                        readonly property bool charging: bat && bat.state === UPowerDeviceState.Charging
                        visible: bat && bat.isPresent && bat.isLaptopBattery
                        text: (charging ? "\uf0e7 " : "\uf240 ") + pct + "%"
                        color: pct <= 15 && !charging ? Theme.warn : Theme.text
                    }

                    // ---- Settings (HyprMod) ----
                    Lbl {
                        text: "\uf013"
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(Theme.settingsCmd)
                        }
                    }

                    // ---- Power: opens the Quickshell power menu ----
                    Lbl {
                        text: "\uf011"
                        font.pixelSize: 16
                        color: Theme.warn
                        MouseArea { anchors.fill: parent; onClicked: root.powerOpen = !root.powerOpen }
                    }
                }
            }
        }
    }
}
