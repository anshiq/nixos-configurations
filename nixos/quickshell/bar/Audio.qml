import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components

// Default sink volume. Scroll adjusts by 5%, middle click mutes,
// left click opens the sound settings.
BarItem {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink && sink.audio ? sink.audio : null
    readonly property int pct: audio ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio ? audio.muted : false

    visible: audio !== null
    icon: muted ? "\u{F075F}" : pct === 0 ? "\u{F0581}" : pct < 34 ? "\u{F057F}" : pct < 67 ? "\u{F0580}" : "\u{F057E}"
    iconColor: muted ? Colors.muted : Colors.foreground
    label: pct + "%"
    labelChars: 4
    labelColor: muted ? Colors.muted : Colors.foreground
    tooltip: (sink ? (sink.description || sink.name) : "") + (muted ? " (muted)" : "") + "\nScroll: volume  Middle click: mute"

    onScrolled: steps => {
        if (audio)
            audio.volume = Math.max(0, Math.min(1, Math.round(audio.volume * 20 + steps) / 20));
    }
    onClicked: button => {
        if (button === Qt.MiddleButton) {
            if (audio)
                audio.muted = !audio.muted;
        } else if (button === Qt.LeftButton) {
            Quickshell.execDetached(["settings-app", "sound"]);
        }
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
