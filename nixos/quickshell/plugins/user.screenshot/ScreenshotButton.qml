import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

// Screenshot (drag the result into any app).
Text {
    text: "󰄀"
    color: Colors.foreground
    font.family: "JetBrainsMono Nerd Font"

    Process {
        id: proc
        command: ["bash", "-c", "$HOME/.config/waybar/scripts/screenshot.sh"]
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        onClicked: proc.startDetached()
    }
}
