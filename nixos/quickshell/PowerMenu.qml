// Power menu. Log out, reboot and shut down ask for confirmation.
// Keys: Up/Down, Enter, Esc (backs out of a confirmation first).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.components

Overlay {
    id: root

    name: "powermenu"
    cardWidth: 300
    cardHeight: content.implicitHeight + 24
    visible: Session.overlay === "powermenu"

    readonly property var actions: [
        {
            id: "lock",
            label: "Lock",
            icon: "\u{F033E}",
            confirm: false
        },
        {
            id: "logout",
            label: "Log out",
            icon: "\u{F0343}",
            confirm: true
        },
        {
            id: "suspend",
            label: "Suspend",
            icon: "\u{F04B2}",
            confirm: false
        },
        {
            id: "reboot",
            label: "Reboot",
            icon: "\u{F0709}",
            confirm: true
        },
        {
            id: "poweroff",
            label: "Shut down",
            icon: "\u{F0425}",
            confirm: true
        }
    ]
    // The action awaiting confirmation, or null.
    property var pending: null
    property int currentIndex: 0
    readonly property var rows: pending ? [
        {
            id: "no",
            label: "Cancel",
            icon: "\u{F0156}"
        },
        {
            id: "yes",
            label: pending.label,
            icon: pending.icon
        }
    ] : actions

    function run(action) {
        Session.close("powermenu");
        switch (action.id) {
        case "lock":
            Session.lock();
            break;
        case "logout":
            Quickshell.execDetached(["uwsm", "stop"]);
            break;
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    function activate(index) {
        const row = root.rows[index];
        if (!row)
            return;
        if (root.pending) {
            if (row.id === "yes")
                root.run(root.pending);
            else
                root.back();
        } else if (row.confirm) {
            root.pending = row;
            root.currentIndex = 0;
        } else {
            root.run(row);
        }
    }

    function back() {
        if (root.pending) {
            root.currentIndex = root.actions.indexOf(root.pending);
            root.pending = null;
        } else {
            Session.close("powermenu");
        }
    }

    onVisibleChanged: {
        root.pending = null;
        root.currentIndex = 0;
        if (visible)
            keys.forceActiveFocus();
    }

    onDismissed: Session.close("powermenu")

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 2

        Text {
            height: 26
            verticalAlignment: Text.AlignVCenter
            leftPadding: 4
            text: root.pending ? `${root.pending.label} now?` : "Power"
            color: Colors.brightForeground
            font.family: Colors.font
            font.pixelSize: 13
            font.bold: true
        }

        Repeater {
            model: root.rows

            ListRow {
                required property var modelData
                required property int index
                width: content.width
                icon: modelData.icon
                text: modelData.label
                current: index === root.currentIndex
                textColor: current ? Colors.selectionForeground : (modelData.id === "yes" ? Colors.red : Colors.foreground)
                onActivated: root.activate(index)
                onHoveredRow: root.currentIndex = index
            }
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const n = root.rows.length;
            if (event.key === Qt.Key_Escape)
                root.back();
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                root.currentIndex = (root.currentIndex + 1) % n;
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                root.currentIndex = (root.currentIndex - 1 + n) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.activate(root.currentIndex);
            else
                return;
            event.accepted = true;
        }
    }
}
