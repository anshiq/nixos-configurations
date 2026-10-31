// Small always-visible pill (bottom-right, click-through) shown while the
// screen is being shared or recorded, so it is visible even when the bar is
// auto-hidden. Sharing is a PipeWire portal screencast (`screen-share`,
// polled every 5 s - PipeWire has no cheap change event for it); recording
// follows screen-record's pidfile (inotify).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    property bool sharing: false
    property bool recording: false
    readonly property string label: sharing && recording ? "REC + SHARING" : sharing ? "SHARING SCREEN" : "REC"

    visible: sharing || recording
    color: "transparent"
    anchors {
        bottom: true
        right: true
    }
    margins.bottom: 10
    margins.right: 10
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    exclusiveZone: 0
    // Empty input region: clicks pass through to whatever is underneath.
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-share-indicator"

    Cmd {
        id: shareCmd
        onFinished: (code, out) => {
            try {
                root.sharing = !!JSON.parse(out).sharing;
            } catch (e) {
                root.sharing = false;
            }
        }
    }

    Cmd {
        id: recordCmd
        onFinished: (code, out) => {
            try {
                root.recording = !!JSON.parse(out).recording;
            } catch (e) {
                root.recording = false;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: !Session.locked
        triggeredOnStart: true
        onTriggered: shareCmd.run(["screen-share", "status", "--json"])
    }

    FileView {
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/screen-record.pid`
        watchChanges: true
        printErrors: false
        onFileChanged: recordCmd.run(["screen-record", "status", "--json"])
        onLoaded: recordCmd.run(["screen-record", "status", "--json"])
        onLoadFailed: recordCmd.run(["screen-record", "status", "--json"])
    }

    Rectangle {
        id: pill
        implicitWidth: row.implicitWidth + 20
        implicitHeight: row.implicitHeight + 10
        radius: height / 2
        color: Colors.background
        border.width: 1
        border.color: Colors.red

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Colors.red
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: Colors.red
                font.family: Colors.font
                font.pixelSize: 11
                font.bold: true
            }
        }
    }
}
