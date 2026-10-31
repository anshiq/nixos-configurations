import QtQuick
import QtQuick.Layouts

// kind: "neutral" (outlined), "primary" (filled with the theme selection
// colors, same as the launcher's highlighted row), "danger" (outlined, red text)
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string kind: "neutral"
    property bool busy: false
    signal clicked

    readonly property color fg: kind === "primary" ? Theme.selectionForeground : (kind === "danger" ? Theme.danger : Theme.brightForeground)

    implicitHeight: 34
    implicitWidth: row.implicitWidth + 28
    radius: Theme.radiusSmall
    opacity: enabled ? 1 : 0.4
    border.width: kind === "primary" ? 0 : 1
    border.color: Theme.border
    color: {
        if (kind === "primary")
            return mouse.containsMouse ? Qt.lighter(Theme.selection, 1.12) : Theme.selection;
        return mouse.containsMouse ? Theme.surfaceHover : "transparent";
    }
    Behavior on color {
        ColorAnimation {
            duration: 90
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Glyph {
            id: glyph
            visible: root.icon !== ""
            text: root.icon
            color: root.fg
            font.pixelSize: 16
            NumberAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    glyph.rotation = 0
            }
        }
        Label {
            visible: root.text !== ""
            text: root.text
            color: root.fg
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled && !root.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
