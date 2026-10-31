import QtQuick
import qs

// Selectable row for overlay lists: optional glyph, text, optional hint
// on the right, optional trailing delete button.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property string hint: ""
    property bool current: false
    property bool deletable: false
    property color textColor: current ? Colors.selectionForeground : Colors.foreground

    signal activated
    signal hoveredRow
    signal deleteRequested

    implicitHeight: 32
    radius: 4
    color: current ? Colors.selection : mouse.containsMouse ? Qt.alpha(Colors.foreground, 0.08) : "transparent"

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
        onEntered: root.hoveredRow()
    }

    Text {
        id: iconText
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: root.icon !== "" ? 18 : 0
        text: root.icon
        color: root.textColor
        font.family: Colors.font
        font.pixelSize: 14
    }

    Text {
        anchors.left: iconText.right
        anchors.leftMargin: root.icon !== "" ? 8 : 0
        anchors.right: hintText.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
        color: root.textColor
        font.family: Colors.font
        font.pixelSize: 13
    }

    Text {
        id: hintText
        anchors.right: deleteButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: root.current ? root.textColor : Qt.alpha(Colors.foreground, 0.5)
        font.family: Colors.font
        font.pixelSize: 11
    }

    Text {
        id: deleteButton
        anchors.right: parent.right
        anchors.rightMargin: root.deletable ? 10 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.deletable ? 16 : 0
        visible: root.deletable && (mouse.containsMouse || deleteMouse.containsMouse || root.current)
        text: "\u{F0156}"
        color: deleteMouse.containsMouse ? Colors.red : root.textColor
        font.family: Colors.font
        font.pixelSize: 13

        MouseArea {
            id: deleteMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            enabled: root.deletable
            onClicked: root.deleteRequested()
        }
    }
}
