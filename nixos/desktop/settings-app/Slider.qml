import QtQuick

// Horizontal slider. `value` is an input only: dragging shows the drag
// position and emits moved(v); the handle returns to `value` on release, so
// the owner decides what the real value becomes (a brightness write can fail).
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property bool dragging: false
    property real dragValue: 0
    signal moved(real value)

    readonly property real shown: dragging ? dragValue : value
    readonly property real position: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    implicitWidth: 220
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: groove
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.border

        Rectangle {
            width: handle.x + handle.width / 2
            height: parent.height
            radius: 3
            color: Theme.accent
        }
    }

    Rectangle {
        id: handle
        width: 18
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: root.position * (root.width - width)
        color: Theme.brightForeground
        border.color: Theme.accent
        border.width: mouse.pressed ? 3 : 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function update(mx) {
            const span = root.width - handle.width;
            const p = span > 0 ? Math.max(0, Math.min(1, (mx - handle.width / 2) / span)) : 0;
            let v = root.from + p * (root.to - root.from);
            if (root.stepSize > 0)
                v = Math.round(v / root.stepSize) * root.stepSize;
            v = Math.max(root.from, Math.min(root.to, v));
            root.dragValue = v;
            root.moved(v);
        }

        onPressed: m => {
            root.dragging = true;
            update(m.x);
        }
        onPositionChanged: m => {
            if (pressed)
                update(m.x);
        }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }
}
