import QtQuick
import qs
import qs.components

// Day and time; the date shows on hover. Ticks once a minute, on the minute.
BarItem {
    id: root

    property date now: new Date()

    label: Qt.formatDateTime(now, "dddd HH:mm")
    tooltip: hovered ? Qt.formatDateTime(new Date(), "d MMMM yyyy") : ""

    function tick() {
        root.now = new Date();
        if (Session.locked)
            return;
        minuteTimer.interval = 60000 - (root.now.getTime() % 60000) + 50;
        minuteTimer.restart();
    }

    Component.onCompleted: tick()

    Connections {
        target: Session
        function onLockedChanged() {
            if (Session.locked)
                minuteTimer.stop();
            else
                root.tick();
        }
    }

    Timer {
        id: minuteTimer
        onTriggered: root.tick()
    }
}
