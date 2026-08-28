// Mirrors waybar's pulseaudio module: icon+volume, muted state,
// on-click mute toggle (kept as `pamixer --toggle-mute`, matching today,
// even though PwNodeAudio.muted is also writable directly).
import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Io
import "../../" // shell root qmldir - exposes the Colors singleton

Item {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property int pct: audio ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio ? audio.muted : false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Text {
        id: label
        anchors.fill: parent
        text: {
            if (root.muted)
                return "󰝟 muted";
            const icon = root.pct === 0 ? "󰖁" : root.pct < 34 ? "󰕿" : root.pct < 67 ? "󰖀" : "󰕾";
            return icon + " " + root.pct + "%";
        }
        color: Colors.foreground
        font.family: "JetBrainsMono Nerd Font"

        MouseArea {
            anchors.fill: parent
            onClicked: toggleMute.startDetached()
        }
    }

    Process {
        id: toggleMute
        command: ["pamixer", "--toggle-mute"]
    }
}
