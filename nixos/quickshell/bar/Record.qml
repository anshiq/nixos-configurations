import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Screen recording toggle. State comes from `screen-record status --json`,
// re-read whenever its pidfile appears or disappears; the elapsed-time
// timer runs only while recording and the bar is visible.
BarItem {
    id: root

    readonly property string pidFile: `${Quickshell.env("XDG_RUNTIME_DIR")}/screen-record.pid`
    property bool recording: false
    property string file: ""
    property real startedAt: 0
    property int elapsed: 0

    function refresh() {
        statusCmd.run(["screen-record", "status", "--json"]);
    }

    function format(s) {
        const pad = n => String(n).padStart(2, "0");
        const h = Math.floor(s / 3600);
        return (h > 0 ? h + ":" : "") + pad(Math.floor(s / 60) % 60) + ":" + pad(s % 60);
    }

    icon: recording ? "\u{F044A}" : "\u{F044B}"
    iconColor: recording ? Colors.red : Colors.foreground
    label: recording ? format(elapsed) : ""
    labelColor: Colors.red
    tooltip: recording ? `Recording${file !== "" ? "\n" + file : ""}\nClick: stop` : "Record screen\nRight click: capture settings"

    onClicked: button => {
        if (button === Qt.RightButton)
            Quickshell.execDetached(["settings-app", "capture"]);
        else if (button === Qt.LeftButton)
            toggleCmd.run(["screen-record", "toggle"]);
    }

    onRecordingChanged: {
        if (recording) {
            startedAt = Date.now();
            elapsed = 0;
            startCmd.run(["stat", "-c", "%Y", pidFile]);
        }
    }

    Component.onCompleted: refresh()

    Cmd {
        id: statusCmd
        onFinished: (code, out) => {
            try {
                const s = JSON.parse(out);
                root.recording = !!s.recording;
                root.file = s.file || "";
            } catch (e) {
                root.recording = false;
                root.file = "";
            }
        }
    }

    Cmd {
        id: toggleCmd
        onFinished: root.refresh()
    }

    // Recording start time, from the pidfile's mtime.
    Cmd {
        id: startCmd
        onFinished: (code, out) => {
            const t = parseInt(out);
            if (code === 0 && !isNaN(t)) {
                root.startedAt = t * 1000;
                root.elapsed = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000));
            }
        }
    }

    FileView {
        path: root.pidFile
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.recording && root.bar !== null && root.bar.active
        onTriggered: root.elapsed = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000))
    }
}
