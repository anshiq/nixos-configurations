// Mirrors waybar's battery module: icon ramp, charging format, warning=30/
// critical=15 states. Reads the same /sys/class/power_supply/BAT* files
// battery-notify.sh already reads (see nixos/waybar/scripts/).
import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Item {
    id: root
    readonly property var icons: ["󰁺", "󰁻", "󰁽", "󰁿", "󰂁", "󰁹"]
    property int capacity: 100
    property bool charging: false
    visible: hasBattery
    property bool hasBattery: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: {
            const icon = root.icons[Math.min(root.icons.length - 1, Math.floor(root.capacity / 100 * root.icons.length))];
            return root.charging ? "󰂄 " + root.capacity + "%" : icon + " " + root.capacity + "%";
        }
        color: root.capacity <= 15 ? Colors.red : (root.capacity <= 30 ? Colors.yellow : Colors.foreground)
        // Nerd Font glyphs above render as blank/tofu in the default Qt
        // application font - every widget using one needs this explicitly,
        // since plain Item/PanelWindow don't propagate a font down like
        // ApplicationWindow does.
        font.family: "JetBrainsMono Nerd Font"
    }

    property var pollLines: []

    Process {
        id: poll
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity /sys/class/power_supply/BAT*/status 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.pollLines.push(line)
        }
        onExited: {
            if (root.pollLines.length >= 2) {
                root.hasBattery = true;
                root.capacity = parseInt(root.pollLines[0], 10) || 0;
                root.charging = root.pollLines[1] === "Charging";
            } else {
                root.hasBattery = false;
            }
            root.pollLines = [];
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }
}
