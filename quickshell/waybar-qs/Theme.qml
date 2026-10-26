pragma Singleton

import Quickshell
import QtQuick

// Central place for colors, sizes and the commands the bar launches.
Singleton {
    // ---- Colors ----
    readonly property color bg:       "#cc131313"
    readonly property color popupBg:  "#f0131313"
    readonly property color border:   "#33ffffff"
    readonly property color hover:    "#22ffffff"
    readonly property color text:     "#e6e1e3"
    readonly property color muted:    "#8f8a90"
    readonly property color accent:   "#5FC7D3"
    readonly property color warn:     "#5FC7D3"

    // ---- Sizes / font ----
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int radius: 8
    readonly property int barHeight: 40
    readonly property int numWorkspaces: 10

    // ---- Commands (edit to taste) ----
    readonly property var launcherCmd: ["rofi", "-show", "drun"]
    readonly property var settingsCmd: ["hyprmod"]            // or ["sh", "-c", "~/.config/quickshell/ryoku-bar/scripts/settings.sh"]
    readonly property var mixerCmd:    ["pavucontrol"]
    readonly property var btManagerCmd: ["blueman-manager"]
    readonly property var netEditorCmd: ["nm-connection-editor"] // fallback if nm-applet's menu isn't in the tray

    readonly property var lockCmd:     ["hyprlock -c .config/hypr/hyprlock.conf"]
    readonly property var logoutCmd:   ["sh", "-c",
    "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]
    readonly property var suspendCmd:  ["systemctl", "suspend"]
    readonly property var rebootCmd:   ["systemctl", "reboot"]
    readonly property var shutdownCmd: ["systemctl", "poweroff"]
}
