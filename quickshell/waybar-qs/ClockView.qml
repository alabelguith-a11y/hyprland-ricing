import QtQuick
import QtQuick.Layouts

// Analog clock + digital time/date. Meant to live inside a PopupPanel.
ColumnLayout {
    id: view

    property bool active: true       // PopupPanel sets this so the timer only runs while shown
    property bool use24h: true
    property bool showSeconds: true
    property date now: new Date()

    Layout.fillWidth: true
    spacing: 8

    Timer {
        interval: 1000
        running: view.active
        repeat: true
        triggeredOnStart: true
        onTriggered: { view.now = new Date(); face.requestPaint(); }
    }

    Canvas {
        id: face
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 170
        Layout.preferredHeight: 170

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.lineCap = "round";

            const cx = width / 2, cy = height / 2;
            const r = Math.min(cx, cy) - 4;
            const t = view.now;
            const sec = t.getSeconds();
            const min = t.getMinutes() + sec / 60;
            const hour = (t.getHours() % 12) + min / 60;

            // face
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.lineWidth = 2;
            ctx.strokeStyle = Theme.border;
            ctx.stroke();

            // hour ticks
            for (let i = 0; i < 12; i++) {
                const a = i * Math.PI / 6;
                const major = i % 3 === 0;
                const r1 = r - (major ? 12 : 7);
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
                ctx.lineTo(cx + Math.cos(a) * (r - 3), cy + Math.sin(a) * (r - 3));
                ctx.lineWidth = major ? 2 : 1;
                ctx.strokeStyle = major ? Theme.text : Theme.muted;
                ctx.stroke();
            }

            // hand: value/period of a full turn, 0 = 12 o'clock
            function hand(value, period, len, w, color) {
                const a = value / period * 2 * Math.PI - Math.PI / 2;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(cx + Math.cos(a) * len, cy + Math.sin(a) * len);
                ctx.lineWidth = w;
                ctx.strokeStyle = color;
                ctx.stroke();
            }
            hand(hour, 12, r * 0.50, 4, Theme.text);
            hand(min,  60, r * 0.75, 3, Theme.text);
            if (view.showSeconds) hand(sec, 60, r * 0.85, 1.5, Theme.accent);

            // center dot
            ctx.beginPath();
            ctx.arc(cx, cy, 4, 0, 2 * Math.PI);
            ctx.fillStyle = Theme.accent;
            ctx.fill();
        }
    }

    Lbl {
        Layout.alignment: Qt.AlignHCenter
        font.pixelSize: 26
        font.bold: true
        color: Theme.accent
        text: Qt.formatTime(view.now, (view.use24h ? "HH:mm" : "hh:mm") + (view.showSeconds ? ":ss" : "")
                                       + (view.use24h ? "" : " AP"))
    }

    Lbl {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.muted
        text: Qt.formatDate(view.now, "dddd, d MMMM yyyy")
    }
}
