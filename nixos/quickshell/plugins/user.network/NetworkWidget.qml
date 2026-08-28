// Mirrors waybar's network module: wifi/ethernet/disconnected states.
//
// Clicking opens NetworkPanel.qml (a native nmcli-driven wifi list) over IPC,
// the same way PowerButton.qml opens PowerMenu.qml - bar plugins are loaded
// into the bar's item tree and can't reference a sibling window under
// ShellRoot directly.
//
// This used to reach into SystemTray.items for nm-applet and call its
// .display() to pop nm-applet's own DBusMenu. That never worked (see the long
// comment at the top of NetworkPanel.qml) and it also meant the wifi list only
// existed as long as a GTK applet happened to be running. Both the applet
// dependency and the tray round trip are gone now.
import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Item {
    id: root
    property string ifname: ""
    property string essid: ""
    property string kind: "disconnected" // "wifi" | "ethernet" | "disconnected"

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: {
            if (root.kind === "wifi")
                return "󰖩  " + (root.essid || "wifi");
            if (root.kind === "ethernet")
                return "󰈀  " + root.ifname;
            return "󰖪  offline";
        }
        color: clickArea.containsMouse ? Colors.accent : Colors.foreground
        font.family: "JetBrainsMono Nerd Font"

        MouseArea {
            id: clickArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: panelProc.startDetached()
        }
    }

    Process {
        id: panelProc
        command: ["quickshell", "ipc", "call", "network", "toggle"]
    }

    property var pollLines: []

    Process {
        id: poll
        command: ["nmcli", "-t", "-f", "TYPE,STATE,DEVICE,CONNECTION", "device"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.pollLines.push(line)
        }
        onExited: {
            const lines = root.pollLines;
            root.pollLines = [];
            // Prefer a wired link when both are up, matching waybar's ordering.
            const connected = lines.filter(l => {
                const f = l.split(":");
                return f[1] === "connected" && f[0] !== "loopback";
            });
            const active = connected.find(l => l.split(":")[0] === "ethernet") || connected[0];
            if (!active) {
                root.kind = "disconnected";
                root.ifname = "";
                root.essid = "";
                return;
            }
            const f = active.split(":");
            root.ifname = f[2];
            root.kind = f[0] === "wifi" ? "wifi" : "ethernet";
            if (root.kind === "wifi") {
                essidPoll.running = true;
            } else {
                // Otherwise a stale SSID from a previous wifi session sticks
                // around and can reappear on the next reconnect.
                root.essid = "";
            }
        }
    }

    Process {
        id: essidPoll
        command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2-"]
        stdout: SplitParser {
            onRead: line => root.essid = line
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }
}
