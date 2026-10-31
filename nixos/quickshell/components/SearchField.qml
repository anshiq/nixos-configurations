import QtQuick
import qs

// Single-line input with a placeholder, styled from Colors.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Search"
    readonly property alias input: input

    // Forwarded before the input handles the key; accept to consume it.
    signal keyPressed(var event)

    implicitHeight: 34
    radius: 4
    color: Qt.alpha(Colors.foreground, 0.06)
    border.width: 1
    border.color: input.activeFocus ? Colors.accent : Colors.muted

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Colors.brightForeground
        selectionColor: Colors.selection
        selectedTextColor: Colors.selectionForeground
        font.family: Colors.font
        font.pixelSize: 13
        clip: true
        focus: true
        Keys.onPressed: event => root.keyPressed(event)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Qt.alpha(Colors.foreground, 0.45)
            font: input.font
            visible: input.text === ""
        }
    }
}
