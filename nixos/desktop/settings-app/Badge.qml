import QtQuick

// Small status pill. `tone: "accent"` fills with the theme accent.
Rectangle {
    id: root
    property string text: ""
    property string tone: "neutral"

    implicitHeight: 20
    implicitWidth: label.implicitWidth + 16
    radius: 10
    color: tone === "accent" ? Theme.accent : "transparent"
    border.width: tone === "accent" ? 0 : 1
    border.color: Theme.border

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 10
        color: root.tone === "accent" ? Theme.background : Theme.textDim
    }
}
