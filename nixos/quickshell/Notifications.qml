// Notification daemon: owns org.freedesktop.Notifications and shows popups
// top-right. Action buttons are rendered and invoked (e.g. KDE Connect's
// pairing Accept/Reject); clicking a popup fires its default action when it has
// one, otherwise dismisses. Each popup expires after its timeout (5 s default);
// resident or never-expiring notifications stay until closed. With
// do-not-disturb on (`dnd` command, state file watched below) only critical
// notifications are shown (plus KDE Connect pairing requests, which the app
// marks ShowPopupsInDndMode and which would otherwise time out); the rest are
// dropped.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.components

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

    // Do not disturb, from `dnd status --json`, re-read whenever the state
    // file changes (the dnd command replaces it atomically).
    property bool dnd: false

    Cmd {
        id: dndCmd
        onFinished: (code, out) => {
            try {
                root.dnd = !!JSON.parse(out).dnd;
            } catch (e) {
                root.dnd = false;
            }
        }
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/desktop/dnd`
        watchChanges: true
        printErrors: false
        onFileChanged: dndCmd.run(["dnd", "status", "--json"])
        onLoaded: dndCmd.run(["dnd", "status", "--json"])
    }

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

    // Card click: run the default action when the notification has one
    // ("default" is how the freedesktop spec names it), else just dismiss.
    function activate(card) {
        const n = root.live[card.notifId];
        if (n) {
            const acts = n.actions;
            for (let i = 0; i < acts.length; i++) {
                if (acts[i].identifier === "default") {
                    acts[i].invoke();
                    return;
                }
            }
        }
        root.dismiss(card.notifId);
    }

    NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        // Advertise actions so apps (KDE Connect pairing requests) send them.
        actionsSupported: true
        onNotification: n => {
            // KDE Connect's notifyrc marks its pairing request
            // ShowPopupsInDndMode=true, so it must stay answerable under DND;
            // it arrives with the event id in this KDE-specific hint.
            const pairingRequest = n.hints["x-kde-eventId"] === "pairingRequest";
            if (root.dnd && n.urgency !== NotificationUrgency.Critical && !pairingRequest)
                return;
            n.tracked = true;
            root.live[n.id] = n;
            popups.append({
                notifId: n.id,
                appName: n.appName,
                summary: n.summary,
                body: n.body,
                image: n.image,
                // Spec: > 0 is the timeout in ms, 0 means never expire, and the
                // negative default falls back to our 5 s. Resident
                // notifications are never auto-closed either.
                timeoutMs: n.expireTimeout > 0 ? n.expireTimeout : (n.expireTimeout === 0 || n.resident) ? 0 : 5000
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

                // Live notification object; its actions (Accept/Reject/...) are
                // invoked by the buttons below.
                readonly property var notif: root.live[card.notifId] ?? null
                readonly property var notifActions: card.notif ? card.notif.actions : []

                width: column.width
                implicitHeight: content.implicitHeight + 24
                color: Colors.background
                border.width: 2
                border.color: Colors.accent

                // timeoutMs 0 = never expire (resident / expire_timeout 0).
                Timer {
                    interval: card.timeoutMs
                    running: card.timeoutMs > 0
                    onTriggered: root.dismiss(card.notifId)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.activate(card)
                }

                Column {
                    id: content
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 8

                    Row {
                        id: inner
                        width: parent.width
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

                    // Action buttons, right-aligned, on top of the click-catcher.
                    Row {
                        id: actionRow
                        x: parent.width - width
                        spacing: 8
                        visible: card.notifActions.length > 0

                        Repeater {
                            model: card.notifActions

                            Rectangle {
                                required property var modelData
                                implicitWidth: actionText.implicitWidth + 20
                                implicitHeight: 24
                                radius: 4
                                color: actionMouse.containsMouse ? Colors.accent : "transparent"
                                border.width: 1
                                border.color: Colors.accent

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    color: actionMouse.containsMouse ? Colors.background : Colors.foreground
                                    font.family: Colors.font
                                    font.pointSize: 11
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
