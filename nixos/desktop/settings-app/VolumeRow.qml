import QtQuick
import QtQuick.Layouts

// Mute button + volume slider + percentage for one PipeWire node.
// `node` is a PwNode that is already bound by a PwObjectTracker (otherwise
// node.audio is null and the row stays disabled).
Item {
    id: root
    property var node: null
    property string iconOn: ""
    property string iconOff: ""
    readonly property var audio: node ? node.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property int pct: audio ? Math.round(audio.volume * 100) : 0

    Layout.fillWidth: true
    implicitHeight: 68
    opacity: audio ? 1 : 0.45

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Theme.radiusSmall
            color: muteMouse.containsMouse ? Theme.surfaceHover : "transparent"
            border.width: 1
            border.color: Theme.border
            Glyph {
                anchors.centerIn: parent
                text: root.muted ? root.iconOff : root.iconOn
                color: root.muted ? Theme.textDim : Theme.brightForeground
            }
            MouseArea {
                id: muteMouse
                anchors.fill: parent
                enabled: root.audio !== null
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.audio.muted = !root.audio.muted
            }
        }

        Slider {
            Layout.fillWidth: true
            enabled: root.audio !== null && !root.muted
            from: 0
            to: 1
            value: root.audio ? Math.min(1, root.audio.volume) : 0
            onMoved: v => root.audio.volume = v
        }

        Label {
            Layout.preferredWidth: 54
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "Muted" : root.pct + "%"
            color: root.muted ? Theme.textDim : Theme.brightForeground
        }
    }
}
