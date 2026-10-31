import QtQuick
import QtQuick.Layouts

// Inline notice. Hidden while `text` is empty, so callers can bind it to an
// error string without managing visibility. kind: "info" | "error"
Rectangle {
    id: root
    property string text: ""
    property string kind: "info"

    visible: text !== ""
    Layout.fillWidth: true
    implicitHeight: visible ? msg.implicitHeight + 24 : 0
    radius: Theme.radiusSmall
    color: Theme.surface
    border.width: 1
    border.color: kind === "error" ? Theme.danger : Theme.border

    Label {
        id: msg
        anchors.fill: parent
        anchors.margins: 12
        text: root.text
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        color: root.kind === "error" ? Theme.danger : Theme.foreground
    }
}
