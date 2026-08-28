// Reuses the existing bluelight-*.sh scripts as-is (state file +
// hyprsunset process management logic stays in bash, unchanged).
import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Item {
    id: root
    property string icon: "☾"
    property string tooltip: ""

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.fill: parent
        text: root.icon
        color: Colors.foreground
    }

    Process {
        id: statusProc
        command: ["bash", "-c", "$HOME/.config/waybar/scripts/bluelight-status.sh"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    root.icon = j.text;
                    root.tooltip = j.tooltip;
                } catch (e) {}
            }
        }
    }

    Process {
        id: toggleProc
        command: ["bash", "-c", "$HOME/.config/waybar/scripts/bluelight-toggle.sh"]
        onExited: statusProc.running = true
    }

    Process {
        id: adjustProc
        stdout: SplitParser {}
        onExited: statusProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        onClicked: toggleProc.running = true
        onWheel: wheel => {
            adjustProc.command = ["bash", "-c", `$HOME/.config/waybar/scripts/bluelight-adjust.sh ${wheel.angleDelta.y > 0 ? 1 : -1}`];
            adjustProc.running = true;
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }
}
