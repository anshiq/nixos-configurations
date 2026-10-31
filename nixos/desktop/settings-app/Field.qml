import QtQuick
import QtQuick.Layouts

// Single-line text input. `password: true` adds a show/hide eye.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool reveal: false
    signal accepted

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 38
    implicitWidth: 220
    radius: Theme.radiusSmall
    color: Theme.background
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        spacing: 6

        TextInput {
            id: input
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            color: Theme.brightForeground
            selectionColor: Theme.selection
            selectedTextColor: Theme.selectionForeground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            echoMode: root.password && !root.reveal ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            selectByMouse: true
            clip: true
            onAccepted: root.accepted()

            Label {
                anchors.fill: parent
                visible: input.text === "" && !input.preeditText
                text: root.placeholder
                color: Theme.textDim
            }
        }

        Glyph {
            visible: root.password
            text: root.reveal ? Icons.eyeOff : Icons.eye
            color: Theme.textDim
            font.pixelSize: 16
            Layout.preferredWidth: 26
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reveal = !root.reveal
            }
        }
    }
}
