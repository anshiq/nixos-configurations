// Mirrors waybar's memory module: "  {}%".
import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Text {
    property real usage: 0
    text: "󰍛  " + Math.round(usage) + "%"
    color: Colors.foreground
    font.family: "JetBrainsMono Nerd Font"

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        // Same reason as Cpu.qml: reload() is async but the Timer reads
        // text() immediately, so without this the first tick parses an empty
        // string and reports 0%.
        blockLoading: true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            const lines = meminfo.text().split("\n");
            const get = key => {
                const line = lines.find(l => l.startsWith(key + ":"));
                return line ? parseInt(line.split(/\s+/)[1], 10) : 0;
            };
            const total = get("MemTotal");
            const available = get("MemAvailable");
            if (total > 0)
                usage = 100 * (1 - available / total);
        }
    }
}
