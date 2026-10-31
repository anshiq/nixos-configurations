import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Full-screen overlay with a centered card. Clicking outside the card
// emits dismissed(); the content handles its own keys (Esc etc).
PanelWindow {
    id: root

    property string name: "overlay"
    property int cardWidth: 400
    property int cardHeight: 300
    default property alias content: card.data

    signal dismissed

    visible: false
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-" + root.name

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardWidth
        height: root.cardHeight
        radius: 6
        color: Colors.background
        border.color: Colors.muted
        border.width: 1

        // Keeps clicks inside the card from reaching the backdrop.
        MouseArea {
            anchors.fill: parent
        }
    }
}
