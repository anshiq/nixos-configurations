// Phase 6: replaces mako. Declaring NotificationServer below is what claims
// the org.freedesktop.Notifications DBus name - no separate daemon/systemd
// unit needed (services.mako.enable removed from desktop/home.nix). Visual
// intent matches the old mako/config-{day,night}: square corners, 360px
// wide, 2px border, 5s auto-dismiss - colors come from the same
// Colors singleton/theme.json Phase 3 wired up, plus an `accent` field on
// every theme (see nixos/themes/) to match mako's border-color exactly
// (it didn't line up with any existing palette entry).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins.top: 10
    margins.right: 10
    implicitWidth: 360
    implicitHeight: column.implicitHeight
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    property var notifObjects: ({})

    function removeById(id) {
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).notifId === id) {
                listModel.remove(i);
                break;
            }
        }
        delete root.notifObjects[id];
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: false
        onNotification: notif => {
            notif.tracked = true;
            root.notifObjects[notif.id] = notif;
            listModel.append({
                notifId: notif.id,
                appName: notif.appName,
                summary: notif.summary,
                body: notif.body,
                image: notif.image,
                timeoutMs: notif.expireTimeout > 0 ? notif.expireTimeout : 5000
            });
            notif.closed.connect(() => root.removeById(notif.id));
        }
    }

    ListModel {
        id: listModel
    }

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: listModel
            delegate: Rectangle {
                id: card
                required property int notifId
                required property string appName
                required property string summary
                required property string body
                required property string image
                required property int timeoutMs

                width: column.width
                implicitHeight: inner.implicitHeight + 24
                radius: 0
                color: Colors.background
                border.width: 2
                border.color: Colors.accent

                Timer {
                    interval: card.timeoutMs
                    running: true
                    onTriggered: {
                        const obj = root.notifObjects[card.notifId];
                        if (obj)
                            obj.dismiss();
                        else
                            root.removeById(card.notifId);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const obj = root.notifObjects[card.notifId];
                        if (obj)
                            obj.dismiss();
                        else
                            root.removeById(card.notifId);
                    }
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
                            color: Colors.foreground
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
