// Notification daemon: owns org.freedesktop.Notifications and shows popups
// top-right. Click dismisses; each popup expires after its timeout (5 s
// default).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs

PanelWindow {
    id: root

    visible: popups.count > 0
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins.top: 10
    margins.right: 10
    implicitWidth: 360
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    // Live notification objects by id; the model holds plain copies.
    property var live: ({})

    function remove(id) {
        for (let i = 0; i < popups.count; i++) {
            if (popups.get(i).notifId === id) {
                popups.remove(i);
                break;
            }
        }
        delete root.live[id];
    }

    function dismiss(id) {
        const n = root.live[id];
        if (n)
            n.dismiss();
        else
            root.remove(id);
    }

    NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: false
        onNotification: n => {
            n.tracked = true;
            root.live[n.id] = n;
            popups.append({
                notifId: n.id,
                appName: n.appName,
                summary: n.summary,
                body: n.body,
                image: n.image,
                timeoutMs: n.expireTimeout > 0 ? n.expireTimeout : 5000
            });
            n.closed.connect(() => root.remove(n.id));
        }
    }

    ListModel {
        id: popups
    }

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: popups

            Rectangle {
                id: card
                required property int notifId
                required property string appName
                required property string summary
                required property string body
                required property string image
                required property int timeoutMs

                width: column.width
                implicitHeight: inner.implicitHeight + 24
                color: Colors.background
                border.width: 2
                border.color: Colors.accent

                Timer {
                    interval: card.timeoutMs
                    running: true
                    onTriggered: root.dismiss(card.notifId)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismiss(card.notifId)
                }

                Row {
                    id: inner
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 10

                    Image {
                        source: card.image
                        visible: card.image !== ""
                        width: 32
                        height: 32
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        width: inner.width - (card.image !== "" ? 42 : 0)
                        spacing: 4

                        Text {
                            width: parent.width
                            text: card.appName + ": " + card.summary
                            textFormat: Text.PlainText
                            color: Colors.brightForeground
                            font.bold: true
                            font.pointSize: 11
                            wrapMode: Text.Wrap
                        }

                        Text {
                            width: parent.width
                            text: card.body
                            color: Colors.foreground
                            font.pointSize: 11
                            wrapMode: Text.Wrap
                            visible: card.body !== ""
                        }
                    }
                }
            }
        }
    }
}
