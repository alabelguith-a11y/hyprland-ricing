pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The one notification server for the whole shell, plus history and Do-Not-Disturb.
// Stop any other daemon (mako, dunst, the old Notification.qml) so only this one owns the bus name.
Singleton {
    id: store

    readonly property var server: srv
    readonly property ListModel history: ListModel {}
    property bool dnd: false
    property int unread: 0
    readonly property int maxHistory: 50

    function remove(i) { history.remove(i); }
    function clear()   { history.clear(); unread = 0; }

    NotificationServer {
        id: srv
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: n => {
            n.tracked = true;                                   // dropped unless tracked

            // volume / brightness OSDs are not worth keeping
            if (n.appName === "VolumeOSD" || n.appName === "BrightnessOSD") return;

            for (let i = 0; i < store.history.count; i++)       // same id = replacement
                if (store.history.get(i).nid === n.id) { store.history.remove(i); break; }

            store.history.insert(0, {
                nid: n.id, appName: n.appName, summary: n.summary, body: n.body,
                image: n.image, appIcon: n.appIcon, time: Date.now()
            });
            while (store.history.count > store.maxHistory) store.history.remove(store.history.count - 1);
            store.unread++;
        }
    }
}
