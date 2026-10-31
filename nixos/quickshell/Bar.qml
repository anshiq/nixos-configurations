// Top bar. Auto-hides to a 1px hover strip; widgets pause their timers
// while it is hidden or the session is locked.
import QtQuick
import Quickshell
import qs
import qs.bar

PanelWindow {
    id: root

    readonly property int expandedHeight: 18
    property bool revealed: true
    // Widgets refresh only while this is true.
    readonly property bool active: revealed && !Session.locked

    anchors {
        left: true
        right: true
        top: true
    }
    implicitHeight: revealed ? expandedHeight : 1
    exclusiveZone: revealed ? expandedHeight : 0
    color: Colors.background

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: hideTimer.start()

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.revealed = false
    }

    // Shared tooltip. tooltipTarget is never reset to null: Quickshell 0.3.0
    // crashes in PopupAnchor when anchor.item goes from an item to null.
    property Item tooltipTarget: null
    property string tooltipText: ""

    function showTooltip(item, text) {
        root.tooltipTarget = item;
        root.tooltipText = text;
    }

    function hideTooltip(item) {
        if (root.tooltipTarget === item)
            root.tooltipText = "";
    }

    SysStats {
        id: stats
        active: root.active
    }

    // Under the widgets; NoButton lets clicks through while still tracking
    // hover over the whole strip.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            hideTimer.stop();
            root.revealed = true;
        }
        onExited: hideTimer.restart()
    }

    Item {
        anchors.fill: parent
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }

        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
        }

        Clock {
            bar: root
            anchors.centerIn: parent
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 2

            Wifi {
                bar: root
                height: parent.height
            }
            Audio {
                bar: root
                height: parent.height
            }
            Cpu {
                bar: root
                stats: stats
                height: parent.height
            }
            Ram {
                bar: root
                stats: stats
                height: parent.height
            }
            Gpu {
                bar: root
                stats: stats
                height: parent.height
            }
            Battery {
                bar: root
                height: parent.height
            }
            Screenshot {
                bar: root
                height: parent.height
            }
            Record {
                bar: root
                height: parent.height
            }
            Clipboard {
                bar: root
                height: parent.height
            }
            Settings {
                bar: root
                height: parent.height
            }
            Power {
                bar: root
                height: parent.height
            }
        }
    }

    PopupWindow {
        visible: root.tooltipText !== "" && root.revealed
        implicitWidth: tooltipLabel.implicitWidth + 12
        implicitHeight: tooltipLabel.implicitHeight + 8
        color: Colors.selection

        anchor {
            item: root.tooltipTarget
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.top: 4
        }

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            color: Colors.selectionForeground
            font.family: Colors.font
            font.pixelSize: 11
        }
    }
}
