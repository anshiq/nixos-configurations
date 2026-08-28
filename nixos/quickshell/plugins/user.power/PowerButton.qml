// Phase 5: opens the native PowerMenu.qml (via IPC, since it's a sibling
// component under ShellRoot, not a parent/child reference) instead of
// shelling out to power-menu.sh.
import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Text {
    id: root
    property bool hovered: false
    font.family: "JetBrainsMono Nerd Font"
    text: "" // nf-fa-power_off
    color: hovered ? Colors.accent : Colors.foreground

    Process {
        id: proc
        command: ["quickshell", "ipc", "call", "powerMenu", "open"]
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: proc.startDetached()
    }
}
