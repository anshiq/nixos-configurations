import QtQuick

// On/off switch. The owner holds the truth: bind `checked` to real state and
// flip it in response to toggled() - so the knob only moves once the backend
// confirms (or the owner chooses to be optimistic).
Item {
    id: root
    property bool checked: false
    property bool busy: false
    signal toggled

    implicitWidth: 46
    implicitHeight: 26
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.muted
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.background : Theme.brightForeground
            opacity: root.busy ? 0.6 : 1
            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
