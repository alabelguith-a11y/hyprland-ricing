import QtQuick
import QtQuick.Layouts

// Month calendar. Click the month title to jump back to today.
ColumnLayout {
    id: cal

    property int firstDay: 1            // 0 = Sunday, 1 = Monday
    property date shown: new Date()
    property date today: new Date()

    function reset() { today = new Date(); shown = new Date(); }
    function shift(n) { shown = new Date(shown.getFullYear(), shown.getMonth() + n, 1); }

    Layout.fillWidth: true
    spacing: 8

    // header: < Month Year >
    RowLayout {
        Layout.fillWidth: true
        Lbl {
            text: "\uf053"; color: Theme.muted; Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
            MouseArea { anchors.fill: parent; onClicked: cal.shift(-1) }
        }
        Lbl {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.bold: true
            color: Theme.accent
            text: Qt.formatDate(cal.shown, "MMMM yyyy")
            MouseArea { anchors.fill: parent; onClicked: cal.reset() }
        }
        Lbl {
            text: "\uf054"; color: Theme.muted; Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
            MouseArea { anchors.fill: parent; onClicked: cal.shift(1) }
        }
    }

    // weekday names
    GridLayout {
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        columnSpacing: 0
        rowSpacing: 0
        Repeater {
            model: 7
            delegate: Lbl {
                required property int index
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignHCenter
                color: Theme.muted
                font.pixelSize: 11
                // 2024-01-07 is a Sunday
                text: Qt.formatDate(new Date(2024, 0, 7 + ((index + cal.firstDay) % 7)), "ddd").slice(0, 2)
            }
        }
    }

    // day grid (6 weeks)
    GridLayout {
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        columnSpacing: 0
        rowSpacing: 2
        Repeater {
            model: 42
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property date d: {
                    const first = new Date(cal.shown.getFullYear(), cal.shown.getMonth(), 1);
                    const offset = (first.getDay() - cal.firstDay + 7) % 7;
                    return new Date(first.getFullYear(), first.getMonth(), 1 - offset + index);
                }
                readonly property bool inMonth: d.getMonth() === cal.shown.getMonth()
                readonly property bool isToday: d.toDateString() === cal.today.toDateString()

                Layout.preferredWidth: 36
                Layout.preferredHeight: 30
                radius: 15
                color: isToday ? Theme.accent : "transparent"

                Lbl {
                    anchors.centerIn: parent
                    text: cell.d.getDate()
                    color: cell.isToday ? "#131313" : cell.inMonth ? Theme.text : Theme.muted
                    opacity: cell.inMonth || cell.isToday ? 1 : 0.5
                    font.bold: cell.isToday
                }
            }
        }
    }
}
