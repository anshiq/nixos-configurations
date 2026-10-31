import QtQuick
import qs

// One bar entry: a glyph plus an optional label. labelChars reserves a
// fixed label width (monospace) so changing numbers don't shift the bar.
Item {
    id: root

    property var bar: null
    property string icon: ""
    property string label: ""
    property int labelChars: 0
    property color iconColor: Colors.foreground
    property color labelColor: Colors.foreground
    property string tooltip: ""
    readonly property bool hovered: mouse.containsMouse

    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: row.implicitHeight

    function syncTooltip() {
        if (!root.bar)
            return;
        if (root.hovered && root.tooltip !== "")
            root.bar.showTooltip(root, root.tooltip);
        else
            root.bar.hideTooltip(root);
    }
    onHoveredChanged: syncTooltip()
    onTooltipChanged: if (hovered)
        syncTooltip()

    TextMetrics {
        id: metrics
        font: labelText.font
        text: "0".repeat(root.labelChars)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            visible: text !== ""
            color: root.iconColor
            font.family: Colors.font
            font.pixelSize: 13
        }

        Text {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            width: root.labelChars > 0 ? Math.ceil(metrics.advanceWidth) : implicitWidth
            horizontalAlignment: root.labelChars > 0 ? Text.AlignRight : Text.AlignLeft
            text: root.label
            visible: text !== ""
            color: root.labelColor
            font.family: Colors.font
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.clicked(event.button)
        // Accumulate so touchpads (small deltas) still step once per notch.
        property real wheelAcc: 0
        onWheel: event => {
            wheelAcc += event.angleDelta.y;
            const steps = Math.trunc(wheelAcc / 120);
            if (steps !== 0) {
                wheelAcc -= steps * 120;
                root.scrolled(steps);
            }
        }
    }
}
