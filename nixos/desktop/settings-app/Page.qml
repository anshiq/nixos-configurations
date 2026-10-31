import QtQuick
import QtQuick.Layouts

// Scrolling page scaffold: big title + subtitle, optional header controls on
// the right, then whatever you put inside goes into a vertical stack.
Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property alias headerTrailing: headerTrailingRow.data
    default property alias content: body.data

    readonly property int contentWidth: Math.min(width - 72, 720)

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 72
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: column
            width: root.contentWidth
            x: Math.max(0, (flick.width - width) / 2)
            y: 36
            spacing: 22

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        text: root.title
                        color: Theme.brightForeground
                        font.pixelSize: Theme.fsTitle
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: text !== ""
                        text: root.subtitle
                        color: Theme.textDim
                        Layout.fillWidth: true
                    }
                }
                RowLayout {
                    id: headerTrailingRow
                    Layout.fillWidth: false
                    spacing: 10
                }
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 12
            }
        }
    }

    Rectangle {
        visible: flick.visibleArea.heightRatio < 1
        x: root.width - 8
        y: flick.visibleArea.yPosition * flick.height
        width: 4
        height: flick.visibleArea.heightRatio * flick.height
        radius: 2
        color: Theme.border
    }
}
