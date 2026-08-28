// Mirrors waybar's cpu module: "  {usage}%", polled every 5s like waybar.
import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Text {
    id: root
    property real usage: 0
    property var lastIdle: -1
    property var lastTotal: -1
    text: "󰻠  " + Math.round(usage) + "%"
    color: Colors.foreground
    font.family: "JetBrainsMono Nerd Font"

    FileView {
        id: stat
        path: "/proc/stat"
        // reload() is asynchronous, and the Timer below reads text() on the
        // very same tick. Without blockLoading that read lands before the file
        // has been parsed, text() returns "", and the delta maths below
        // produces NaN - which is why the bar showed "NaN%" for the first ~15
        // seconds of every session. /proc/stat is a few hundred bytes off a
        // virtual filesystem, so reading it synchronously costs nothing.
        blockLoading: true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            const line = stat.text().split("\n")[0]; // "cpu  user nice system idle iowait irq softirq ..."
            const parts = line.trim().split(/\s+/).slice(1).map(Number);
            // Belt and braces: a short read here would silently poison
            // lastIdle/lastTotal with NaN and the widget would never recover
            // on its own.
            if (parts.length < 5 || parts.some(isNaN))
                return;
            const idle = parts[3] + parts[4];
            const total = parts.reduce((a, b) => a + b, 0);
            if (root.lastTotal >= 0) {
                const totalDelta = total - root.lastTotal;
                const idleDelta = idle - root.lastIdle;
                if (totalDelta > 0)
                    root.usage = 100 * (1 - idleDelta / totalDelta);
            }
            root.lastIdle = idle;
            root.lastTotal = total;
        }
    }
}
