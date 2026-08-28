// Mirrors waybar's clock module format: "  {:%a %d %b  %H:%M}".
import QtQuick
import "../../" // shell root qmldir - exposes the Colors singleton

Text {
    id: root
    property string now: ""
    text: "  " + now
    color: Colors.foreground

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            const pad = n => String(n).padStart(2, "0");
            root.now = `${days[d.getDay()]} ${pad(d.getDate())} ${months[d.getMonth()]}  ${pad(d.getHours())}:${pad(d.getMinutes())}`;
        }
    }
}
