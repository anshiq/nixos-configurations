import QtQuick
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

// Screen recording (OBS Studio) - opens minimized to the tray.
Text {
    text: "󰑋"
    color: Colors.foreground
    font.family: "JetBrainsMono Nerd Font"

    Process {
        id: proc
        command: ["obs", "--minimize-to-tray"]
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        onClicked: proc.startDetached()
    }
}
