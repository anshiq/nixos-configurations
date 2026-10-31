import QtQuick

// Four ascending bars; `strength` is 0-100 (nmcli's SIGNAL column).
Row {
    id: root
    property int strength: 0
    readonly property int lit: strength <= 0 ? 0 : Math.min(4, Math.ceil(strength / 25))

    spacing: 2
    Repeater {
        model: 4
        Rectangle {
            required property int index
            width: 4
            height: 5 + index * 4
            anchors.bottom: parent.bottom
            radius: 1
            color: index < root.lit ? Theme.brightForeground : Theme.muted
        }
    }
}
