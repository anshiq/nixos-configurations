import QtQuick
import qs

// Selectable row for overlay lists: optional glyph or image icon, text, optional hint
// on the right, optional trailing delete button.
Rectangle {
    id: root

    property string icon: ""
    // Image URL for a real (themed) icon; shown instead of the glyph above.
    property string iconSource: ""
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

    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSource !== "" ? 22 : root.icon !== "" ? 18 : 0
        height: 22

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconSource === ""
            text: root.icon
            color: root.textColor
            font.family: Colors.font
            font.pixelSize: 14
        }

        Image {
            anchors.fill: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize: Qt.size(44, 44)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
    }

    Text {
        anchors.left: iconBox.right
        anchors.leftMargin: root.icon !== "" || root.iconSource !== "" ? 8 : 0
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
