// Clipboard history (cliphist). The list is loaded each time the panel
// opens and dropped when it closes.
// Keys: type to filter, Up/Down, Enter copies, Shift+Delete deletes,
// Ctrl+O reads the text out of an image entry (ocr), Esc.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.components

Overlay {
    id: root

    name: "clipboard"
    cardWidth: 600
    cardHeight: 460
    visible: Session.overlay === "clipboard"

    // [{ line, text, image }], newest first, as cliphist lists them.
    property var entries: []
    property var filtered: []
    property bool loading: false
    property bool confirmClear: false

    function parse(out) {
        const result = [];
        for (const line of out.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            const preview = line.slice(tab + 1);
            // "[[ binary data 12 KiB png 1920x1080 ]]"
            const m = /^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/.exec(preview);
            if (m)
                result.push({
                    line: line,
                    text: `Image ${m[3]} ${m[2]}`,
                    hint: m[1],
                    image: true
                });
            else
                result.push({
                    line: line,
                    text: preview.replace(/\s+/g, " ").trim(),
                    hint: "",
                    image: false
                });
        }
        return result;
    }

    function updateFilter() {
        const q = search.text.toLowerCase();
        root.filtered = q === "" ? root.entries : root.entries.filter(e => e.text.toLowerCase().includes(q));
        list.currentIndex = root.filtered.length > 0 ? 0 : -1;
    }

    function copy(index) {
        const e = root.filtered[index];
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", e.line]);
        Session.close("clipboard");
    }

    // OCR an image entry: the text goes to the clipboard and a notification.
    function ocr(index) {
        const e = root.filtered[index];
        if (!e || !e.image)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | ocr --stdin", "sh", e.line]);
        Session.close("clipboard");
    }

    function remove(index) {
        const e = root.filtered[index];
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", e.line]);
        root.entries = root.entries.filter(x => x !== e);
        const keep = list.currentIndex;
        root.filtered = root.filtered.filter(x => x !== e);
        list.currentIndex = Math.min(keep, root.filtered.length - 1);
    }

    function clearAll() {
        if (!root.confirmClear) {
            root.confirmClear = true;
            return;
        }
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.entries = [];
        root.filtered = [];
        root.confirmClear = false;
    }

    onVisibleChanged: {
        root.confirmClear = false;
        search.text = "";
        if (visible) {
            root.loading = true;
            listCmd.run(["cliphist", "list"]);
            search.input.forceActiveFocus();
        } else {
            root.entries = [];
            root.filtered = [];
        }
    }

    onDismissed: Session.close("clipboard")

    Cmd {
        id: listCmd
        onFinished: (code, out) => {
            root.loading = false;
            root.entries = code === 0 ? root.parse(out) : [];
            root.updateFilter();
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Row {
            id: header
            width: parent.width
            height: 34
            spacing: 8

            SearchField {
                id: search
                width: parent.width - clearButton.width - parent.spacing
                height: parent.height
                placeholder: "Filter clipboard history"
                onTextChanged: root.updateFilter()

                onKeyPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        Session.close("clipboard");
                    } else if (event.key === Qt.Key_Down) {
                        list.incrementCurrentIndex();
                    } else if (event.key === Qt.Key_Up) {
                        list.decrementCurrentIndex();
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.copy(list.currentIndex);
                    } else if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
                        root.ocr(list.currentIndex);
                    } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                        root.remove(list.currentIndex);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            Rectangle {
                id: clearButton
                width: clearLabel.implicitWidth + 20
                height: parent.height
                radius: 4
                color: root.confirmClear ? Colors.red : clearMouse.containsMouse ? Qt.alpha(Colors.foreground, 0.12) : Qt.alpha(Colors.foreground, 0.06)

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: root.confirmClear ? "Confirm clear" : "Clear all"
                    color: root.confirmClear ? Colors.background : Colors.foreground
                    font.family: Colors.font
                    font.pixelSize: 12
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.clearAll()
                    onExited: root.confirmClear = false
                }
            }
        }

        ListView {
            id: list
            anchors.top: header.bottom
            anchors.topMargin: 8
            anchors.bottom: footer.top
            anchors.bottomMargin: 6
            width: parent.width
            clip: true
            spacing: 2
            model: root.filtered
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: ListRow {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                icon: modelData.image ? "\u{F02E9}" : ""
                text: modelData.text
                hint: modelData.hint
                current: index === ListView.view.currentIndex
                deletable: true
                onActivated: root.copy(index)
                onHoveredRow: list.currentIndex = index
                onDeleteRequested: root.remove(index)
            }
        }

        Text {
            anchors.centerIn: list
            visible: root.filtered.length === 0
            text: root.loading ? "Loading..." : root.entries.length === 0 ? "Clipboard history is empty" : "No matches"
            color: Qt.alpha(Colors.foreground, 0.5)
            font.family: Colors.font
            font.pixelSize: 13
        }

        Text {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            text: "Enter copy   Ctrl+O read text from image   Shift+Del delete   Esc close"
            horizontalAlignment: Text.AlignRight
            color: Qt.alpha(Colors.foreground, 0.5)
            font.family: Colors.font
            font.pixelSize: 11
        }
    }
}
