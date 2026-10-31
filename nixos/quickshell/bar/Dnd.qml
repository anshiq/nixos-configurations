import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Do-not-disturb toggle. State comes from `dnd status --json`, re-read
// whenever the state file changes (it is replaced atomically by `dnd`).
BarItem {
    id: root

    property bool dnd: false

    icon: dnd ? "\u{F009B}" : "\u{F009A}"
    iconColor: dnd ? Colors.red : Colors.foreground
    tooltip: dnd ? "Do not disturb: on\nClick: turn off" : "Do not disturb: off\nClick: silence notifications"

    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["dnd", "toggle"]);
    }

    Cmd {
        id: statusCmd
        onFinished: (code, out) => {
            try {
                root.dnd = !!JSON.parse(out).dnd;
            } catch (e) {
                root.dnd = false;
            }
        }
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/desktop/dnd`
        watchChanges: true
        printErrors: false
        onFileChanged: statusCmd.run(["dnd", "status", "--json"])
        onLoaded: statusCmd.run(["dnd", "status", "--json"])
    }
}
