// Clipboard history for Quickshell (text + images), built on cliphist + wl-clipboard.
//
// Needs:  sudo pacman -S cliphist wl-clipboard
// Use:    put  Clipboard { id: clipboard }  inside ShellRoot (Bar.qml), then
//         toggle with  clipboard.open = !clipboard.open  (bar icon) or
//         qs -p <path to Bar.qml> ipc call clipboard toggle   (keybind)
//
// Keys: type to search · ↑ ↓ move · Enter copy · Ctrl+D delete entry · Esc close
// Picking an entry puts it back on the clipboard; paste it with Ctrl+V as usual.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ---------------- settings ----------------
    property bool startWatchers: true   // start wl-paste → cliphist if nothing else already does
    property int maxEntries: 150
    property int maxThumbs: 24          // how many recent images get a thumbnail
    // ------------------------------------------

    property bool open: false
    property var all: []                // parsed cliphist entries
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-clip"

    // ---------- data ----------
    function refresh() { lister.running = true; }

    function parseList(text) {
        const lines = text.split("\n").filter(l => l.length > 0).slice(0, root.maxEntries);
        const out = [], ids = [];
        for (const l of lines) {
            const t = l.indexOf("\t");
            if (t < 0) continue;
            const cid = l.substring(0, t);
            const prev = l.substring(t + 1).trim();
            const img = prev.startsWith("[[ binary data");
            out.push({ cid: cid, preview: prev, raw: l, isImage: img,
                       thumb: img ? "file://" + root.thumbDir + "/" + cid : "" });
            if (img && ids.length < root.maxThumbs) ids.push(cid);
        }
        root.all = out;
        if (ids.length > 0) {
            // decode image entries to files first so thumbnails exist when the list shows
            thumbs.command = ["sh", "-c",
                'd="$1"; shift; mkdir -p "$d"; for id; do [ -s "$d/$id" ] || cliphist decode "$id" > "$d/$id"; done',
                "sh", root.thumbDir].concat(ids);
            thumbs.running = true;
        } else {
            rebuild();
        }
    }

    function rebuild() {
        items.clear();
        const q = search.text.toLowerCase();
        for (const e of root.all)
            if (q === "" || e.preview.toLowerCase().includes(q)) items.append(e);
        list.currentIndex = items.count > 0 ? 0 : -1;
    }

    function pick(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", e.cid]);
        open = false;
    }

    function remove(e) {
        if (!e) return;
        deleter.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", e.raw];
        deleter.running = true;
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.all = [];
        rebuild();
    }

    ListModel { id: items }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.parseList(text) }
    }
    Process { id: thumbs; onExited: root.rebuild() }
    Process { id: deleter; onExited: root.refresh() }

    // keeps cliphist fed. Skipped if a wl-paste → cliphist watcher already runs (e.g. your autostart).
    // (pgrep -x matches the process *name*, so this script's own text can't trigger a false "already running")
    Process {
        running: root.startWatchers
        command: ["sh", "-c",
            "pgrep -xa wl-paste | grep -q cliphist || " +
            "{ wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store & wait; }"]
        stderr: SplitParser { onRead: data => console.log("clipboard watcher:", data) }
        onExited: code => console.log("clipboard watcher exited:", code)
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open = !root.open; }
        function open(): void   { root.open = true; }
        function close(): void  { root.open = false; }
    }

    // ================= UI =================
    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-clipboard"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "#99000000"

        onVisibleChanged: if (visible) { search.text = ""; root.refresh(); search.forceActiveFocus(); }

        MouseArea { anchors.fill: parent; onClicked: root.open = false }   // click outside = close

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: Math.min(560, win.height - 80)
            radius: Theme.radius + 4
            color: Theme.popupBg
            border.color: Theme.border
            border.width: 1

            MouseArea { anchors.fill: parent }   // clicks on the panel don't close it

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Lbl { text: "\uf0ea  Clipboard"; font.bold: true; color: Theme.accent; Layout.fillWidth: true }
                    Lbl { text: items.count + (items.count === 1 ? " entry" : " entries"); color: Theme.muted }
                    Lbl {
                        text: "\uf1f8  Clear all"
                        color: Theme.muted
                        MouseArea { anchors.fill: parent; onClicked: root.wipe() }
                    }
                }

                Rectangle {   // search box
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 8
                    color: Theme.hover
                    border.color: Theme.border

                    TextInput {
                        id: search
                        anchors.fill: parent
                        anchors.margins: 10
                        color: Theme.text
                        selectionColor: Theme.accent
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        onTextChanged: root.rebuild()

                        Keys.onPressed: event => {
                            const n = items.count;
                            if (event.key === Qt.Key_Escape) { root.open = false; event.accepted = true; }
                            else if (event.key === Qt.Key_Down) { list.currentIndex = Math.min(n - 1, list.currentIndex + 1); event.accepted = true; }
                            else if (event.key === Qt.Key_Up)   { list.currentIndex = Math.max(0, list.currentIndex - 1); event.accepted = true; }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (list.currentIndex >= 0) root.pick(items.get(list.currentIndex));
                                event.accepted = true;
                            }
                            else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
                                if (list.currentIndex >= 0) root.remove(items.get(list.currentIndex));
                                event.accepted = true;
                            }
                        }

                        Text {
                            visible: search.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type to search…"
                            color: Theme.muted
                            font: search.font
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: items
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property string cid
                        required property string preview
                        required property string raw
                        required property bool isImage
                        required property string thumb

                        width: ListView.view.width
                        height: isImage ? 64 : 40
                        radius: 8
                        color: ListView.isCurrentItem ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: ListView.isCurrentItem ? Theme.accent : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Item {   // image thumbnail
                                visible: row.isImage
                                Layout.preferredWidth: 72
                                Layout.fillHeight: true
                                Image {
                                    id: img
                                    anchors.fill: parent
                                    source: row.thumb
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    sourceSize: Qt.size(160, 128)
                                }
                                Lbl { anchors.centerIn: parent; visible: img.status !== Image.Ready; text: "\uf03e"; color: Theme.muted }
                            }

                            Lbl {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: row.isImage
                                      ? "Image  ·  " + row.preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "")
                                      : row.preview
                            }

                            Lbl {   // delete
                                visible: rowMouse.containsMouse || row.ListView.isCurrentItem
                                text: "\uf00d"
                                color: Theme.muted
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: root.remove(items.get(row.index))
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            anchors.rightMargin: 30      // leave the ✕ clickable
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: root.pick(items.get(row.index))
                        }
                    }

                    Lbl {
                        anchors.centerIn: parent
                        visible: items.count === 0
                        color: Theme.muted
                        text: search.text === "" ? "Nothing copied yet" : "No matches"
                    }
                }

                Lbl {
                    Layout.alignment: Qt.AlignHCenter
                    color: Theme.muted
                    font.pixelSize: 11
                    text: "↑ ↓  move   ·   Enter  copy   ·   Ctrl+D  delete   ·   Esc  close"
                }
            }
        }
    }
}
