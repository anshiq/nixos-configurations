import QtQuick
import QtQuick.Layouts

// One row of a Card: optional icon, title + subtitle, and whatever you put
// inside the element on the right (toggle, button, badge...).
//
// Dividers are explicit: every row draws a hairline on top unless `first`.
// (Auto-detecting "first child" inside a Repeater-populated layout is not
// reliable, and a missing/extra line is worse than a one-word property.)
Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color iconColor: Theme.foreground
    property color titleColor: Theme.brightForeground
    property bool first: false
    property bool clickable: false
    property int minHeight: Theme.rowHeight
    signal clicked

    // Custom leading element (e.g. signal bars) instead of a glyph.
    property alias leading: leadingRow.data
    default property alias trailing: trailingRow.data

    Layout.fillWidth: true
    implicitHeight: Math.max(minHeight, content.implicitHeight + 22)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.radiusSmall
        color: root.clickable && mouse.containsMouse ? Theme.surfaceHover : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }
    }

    Rectangle {
        visible: !root.first
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        height: 1
        color: Theme.border
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        spacing: 14

        // Nested layouts default to Layout.fillWidth: true, which would make
        // these two split the row's spare width with the title column.
        RowLayout {
            id: leadingRow
            Layout.fillWidth: false
            spacing: 0
        }

        Glyph {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            Layout.preferredWidth: 28
            Layout.minimumWidth: 28
            Layout.maximumWidth: 28
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: root.title
                color: root.titleColor
                Layout.fillWidth: true
            }
            Label {
                visible: text !== ""
                text: root.subtitle
                color: Theme.textDim
                font.pixelSize: Theme.fsSmall
                wrapMode: Text.Wrap
                maximumLineCount: 3
                Layout.fillWidth: true
            }
        }

        RowLayout {
            id: trailingRow
            Layout.fillWidth: false
            spacing: 10
        }
    }
}
