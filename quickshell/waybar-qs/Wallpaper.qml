// Wallpaper picker + renderer for Quickshell.
//
//  - Draws the wallpaper itself (crossfade) on every screen. Your choice is saved to
//    `stateFile` and restored on start (first image / random if nothing was saved yet).
//  - A full-screen carousel lists every image in `wallDir`; scroll, pick, apply.
//
// Use inside your bar:   Wallpaper {}            (put it inside ShellRoot in Bar.qml)
// Or standalone:         qs -p Wallpaper.qml
// Open the picker:       qs -p <path to Bar.qml or Wallpaper.qml> ipc call wallpaper toggle
//
// Keys in the picker: ← → (or scroll wheel) browse · Enter / click = apply · R = random · Esc = close

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ---------------- settings ----------------
    property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property bool renderBackground: true   // false if swww/awww/hyprpaper already draws your wallpaper
    property var applyCmd: []              // optional, path is appended, e.g. ["awww", "img"]
    property var postCmd: []               // optional hook after applying, e.g. ["matugen", "image"]
    property bool rememberChoice: true     // save the chosen wallpaper and restore it on start
    property string stateFile: Quickshell.env("HOME") + "/.local/state/qs-wallpaper"
    property bool randomOnStart: false     // when nothing is saved: false = first image, true = random
    property bool writeLockConf: true      // also write a hyprlock include file (see lockConf)
    property string lockConf: Quickshell.env("HOME") + "/.local/state/qs-wallpaper.conf"

    readonly property color cAccent: "#ffade4"
    readonly property color cText:   "#e6e1e3"
    readonly property color cMuted:  "#8f8a90"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    // ------------------------------------------

    property string current: ""   // absolute path of the active wallpaper
    property bool open: false
    property bool stateChecked: false   // saved choice has been read (or there is none)
    onStateCheckedChanged: pickDefault()

    Component.onCompleted: {
        console.log("wallpaper: loaded, dir =", wallDir);
        if (!rememberChoice) stateChecked = true;
    }

    // hyprlock can't run shell commands, so we give it a file to `source` that defines $wallpaper
    function writeLock(path) {
        if (!writeLockConf || !path) return;
        console.log("wallpaper: writing", lockConf, "->", path);
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '$wallpaper = %s\\n' \"$2\" > \"$1\"", "sh", lockConf, path]);
    }

    onCurrentChanged: writeLock(current)

    function save(path) {
        if (!rememberChoice) return;
        console.log("wallpaper: saving", stateFile, "->", path);
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "sh", stateFile, path]);
    }

    // used when nothing was saved
    function pickDefault() {
        if (stateChecked && current === "" && walls.status === FolderListModel.Ready && walls.count > 0)
            current = walls.get(randomOnStart ? Math.floor(Math.random() * walls.count) : 0, "filePath");
    }

    function apply(path) {
        if (!path) return;
        current = path;
        save(path);
        if (applyCmd.length > 0) Quickshell.execDetached(applyCmd.concat([path]));
        if (postCmd.length > 0)  Quickshell.execDetached(postCmd.concat([path]));
        open = false;
    }

    function randomPick() {
        if (walls.count > 0) apply(walls.get(Math.floor(Math.random() * walls.count), "filePath"));
    }

    function syncIndex() {
        for (let i = 0; i < walls.count; i++) {
            if (walls.get(i, "filePath") === current) { list.currentIndex = i; return; }
        }
        list.currentIndex = 0;
    }

    // saved wallpaper
    FileView {
        path: root.rememberChoice ? root.stateFile : ""
        onLoaded: { root.current = text().trim(); root.stateChecked = true; }
        onLoadFailed: { root.stateChecked = true; root.pickDefault(); }
    }

    // every image in the folder
    FolderListModel {
        id: walls
        folder: "file://" + root.wallDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        onCountChanged: if (root.open) root.syncIndex()
        onStatusChanged: root.pickDefault()
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.open = !root.open; }
        function open(): void   { root.open = true; }
        function close(): void  { root.open = false; }
        function random(): void { root.randomPick(); }
    }

    // ================= wallpaper renderer =================
    Variants {
        model: root.renderBackground ? Quickshell.screens : []

        PanelWindow {
            id: bg
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "qs-wallpaper"
            color: "black"

            function load() { fade.source = root.current !== "" ? "file://" + root.current : ""; }
            Component.onCompleted: load()
            Connections { target: root; function onCurrentChanged() { bg.load(); } }

            Image {
                id: base
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize: Qt.size(bg.modelData.width, bg.modelData.height)
            }
            Image {   // new wallpaper fades in over the old one
                id: fade
                anchors.fill: parent
                opacity: 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                sourceSize: Qt.size(bg.modelData.width, bg.modelData.height)
                onStatusChanged: if (status === Image.Ready) fadeIn.restart()
            }
            NumberAnimation {
                id: fadeIn
                target: fade
                property: "opacity"
                from: 0; to: 1
                duration: 700
                easing.type: Easing.InOutQuad
                onFinished: { base.source = fade.source; fade.opacity = 0; }
            }
        }
    }

    // ================= picker =================
    PanelWindow {
        id: picker
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-wallpaper-picker"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "#d9000000"

        onVisibleChanged: if (visible) { root.syncIndex(); keys.forceActiveFocus(); }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const n = walls.count;
                if (event.key === Qt.Key_Escape) root.open = false;
                else if (event.key === Qt.Key_Left  || event.key === Qt.Key_H) list.currentIndex = Math.max(0, list.currentIndex - 1);
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) list.currentIndex = Math.min(n - 1, list.currentIndex + 1);
                else if (event.key === Qt.Key_Home) list.currentIndex = 0;
                else if (event.key === Qt.Key_End)  list.currentIndex = Math.max(0, n - 1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.apply(walls.get(list.currentIndex, "filePath"));
                else if (event.key === Qt.Key_R) root.randomPick();
            }

            MouseArea { anchors.fill: parent; onClicked: root.open = false }   // click background = close

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: 22

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Wallpaper"
                    color: root.cAccent
                    font { family: root.fontFamily; pixelSize: 22; bold: true }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: 280
                    orientation: ListView.Horizontal
                    model: walls
                    spacing: 24
                    cacheBuffer: 2000
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - 160
                    preferredHighlightEnd: width / 2 + 160
                    highlightMoveDuration: 250

                    WheelHandler {   // scroll wheel steps through wallpapers
                        onWheel: event => {
                            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            list.currentIndex = Math.max(0, Math.min(walls.count - 1,
                                                                      list.currentIndex + (d > 0 ? -1 : 1)));
                        }
                    }

                    delegate: Item {
                        id: card
                        required property int index
                        required property string fileName
                        required property string filePath
                        required property url fileUrl
                        readonly property bool selected: ListView.isCurrentItem

                        width: 320
                        height: list.height

                        Rectangle {
                            anchors.centerIn: parent
                            width: card.selected ? 320 : 250
                            height: card.selected ? 200 : 156
                            radius: 12
                            color: "#222222"
                            border.width: card.selected ? 3 : 1
                            border.color: card.selected ? root.cAccent : "#33ffffff"
                            clip: true
                            opacity: card.selected ? 1.0 : 0.65
                            Behavior on width   { NumberAnimation { duration: 150 } }
                            Behavior on height  { NumberAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: card.fileUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(640, 400)
                            }

                            Text {   // marks the wallpaper currently in use
                                visible: card.filePath === root.current
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                text: "\uf00c"
                                color: root.cAccent
                                font { family: root.fontFamily; pixelSize: 16 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: card.selected ? root.apply(card.filePath) : list.currentIndex = card.index
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: walls.count === 0 ? "No images found in " + root.wallDir
                          : (list.currentItem ? list.currentItem.fileName : "")
                    color: root.cText
                    font { family: root.fontFamily; pixelSize: 16 }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "← →  or scroll   ·   Enter / click  apply   ·   R  random   ·   Esc  close"
                    color: root.cMuted
                    font { family: root.fontFamily; pixelSize: 12 }
                }
            }
        }
    }
}
